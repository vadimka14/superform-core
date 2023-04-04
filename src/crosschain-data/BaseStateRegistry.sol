// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import "@openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IBaseStateRegistry} from "../interfaces/IBaseStateRegistry.sol";
import {IAmbImplementation} from "../interfaces/IAmbImplementation.sol";
import {PayloadState, AMBMessage, AMBFactoryMessage} from "../types/DataTypes.sol";
import {ISuperRegistry} from "../interfaces/ISuperRegistry.sol";

/// @title Cross-Chain AMB (Arbitrary Message Bridge) Aggregator Base
/// @author Zeropoint Labs
/// @notice stores, sends & process message sent via various messaging ambs.
abstract contract BaseStateRegistry is IBaseStateRegistry, AccessControl {
    /*///////////////////////////////////////////////////////////////
                    ACCESS CONTROL ROLE CONSTANTS
    //////////////////////////////////////////////////////////////*/
    bytes32 public constant CORE_CONTRACTS_ROLE =
        keccak256("CORE_CONTRACTS_ROLE");
    bytes32 public constant IMPLEMENTATION_CONTRACTS_ROLE =
        keccak256("IMPLEMENTATION_CONTRACTS_ROLE");
    bytes32 public constant PROCESSOR_ROLE = keccak256("PROCESSOR_ROLE");
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    /*///////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev superformChainid
    uint16 public immutable chainId;
    uint256 public payloadsCount;

    mapping(uint8 => IAmbImplementation) public amb;
    mapping(bytes => uint256) public messageQuorum;

    /// @dev stores all received payloads after assigning them an unique identifier upon receiving.
    mapping(uint256 => bytes) public payload;

    /// @dev maps payloads to their status
    mapping(uint256 => PayloadState) public payloadTracking;

    ISuperRegistry public superRegistry;

    /*///////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    ///@dev set up admin during deployment.
    constructor(uint16 chainId_) {
        if (chainId_ == 0) revert INVALID_INPUT_CHAIN_ID();

        chainId = chainId_;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*///////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    receive() external payable {}

    /// @dev allows admin to update amb implementations.
    /// @param ambId_ is the propreitory amb id.
    /// @param ambImplementation_ is the implementation address.
    function configureAmb(
        uint8 ambId_,
        address ambImplementation_
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (ambId_ == 0) {
            revert INVALID_BRIDGE_ID();
        }

        if (ambImplementation_ == address(0)) {
            revert INVALID_BRIDGE_ADDRESS();
        }

        amb[ambId_] = IAmbImplementation(ambImplementation_);
        emit AmbConfigured(ambId_, ambImplementation_);
    }

    /// @dev allows core contracts to send data to a destination chain.
    /// @param ambId_ is the identifier of the message amb to be used.
    /// @param dstChainId_ is the internal chainId used throughtout the protocol.
    /// @param message_ is the crosschain data to be sent.
    /// @param extraData_ defines all the message amb specific information.
    /// NOTE: dstChainId maps with the message amb's propreitory chain Id.
    function dispatchPayload(
        uint8 ambId_,
        uint8[] memory secAmbId_,
        uint16 dstChainId_,
        bytes memory message_,
        bytes memory extraData_
    ) external payable virtual override onlyRole(CORE_CONTRACTS_ROLE) {
        _dispatchPayload(ambId_, dstChainId_, message_, extraData_);
        _dispatchProof(ambId_, secAmbId_, dstChainId_, message_, extraData_);
    }

    /// @dev allows core contracts to send data to all available destination chains
    function broadcastPayload(
        uint8 ambId_,
        uint8[] memory secAmbId_,
        bytes memory message_,
        bytes memory extraData_
    ) external payable virtual override onlyRole(CORE_CONTRACTS_ROLE) {
        _broadcastPayload(ambId_, message_, extraData_);
        _broadcastProof(ambId_, secAmbId_, message_, extraData_);
    }

    /// @dev allows state registry to receive messages from amb implementations.
    /// @param srcChainId_ is the internal chainId from which the data is sent.
    /// @param message_ is the crosschain data received.
    /// NOTE: Only {IMPLEMENTATION_CONTRACT} role can call this function.
    function receivePayload(
        uint16 srcChainId_,
        bytes memory message_
    ) external virtual override onlyRole(IMPLEMENTATION_CONTRACTS_ROLE) {
        AMBMessage memory data = abi.decode(message_, (AMBMessage));

        if (data.params.length == 32) {
            /// assuming 32 bytes length is always proof
            /// @dev should validate this later
            messageQuorum[data.params] += 1;

            emit ProofReceived(data.params);
        } else {
            ++payloadsCount;
            payload[payloadsCount] = message_;

            emit PayloadReceived(srcChainId_, chainId, payloadsCount);
        }
    }

    /// @dev allows accounts with {PROCESSOR_ROLE} to process any successful cross-chain payload.
    /// @param payloadId_ is the identifier of the cross-chain payload.
    /// NOTE: function can only process successful payloads.
    function processPayload(
        uint256 payloadId_
    ) external payable virtual override onlyRole(PROCESSOR_ROLE) {}

    /// @dev allows accounts with {PROCESSOR_ROLE} to revert payload that fail to revert state changes on source chain.
    /// @param payloadId_ is the identifier of the cross-chain payload.
    /// @param ambId_ is the identifier of the cross-chain amb to be used to send the acknowledgement.
    /// @param extraData_ is any message amb specific override information.
    /// NOTE: function can only process failing payloads.
    function revertPayload(
        uint256 payloadId_,
        uint256 ambId_,
        bytes memory extraData_
    ) external payable virtual override onlyRole(PROCESSOR_ROLE) {}

    function _dispatchPayload(
        uint8 ambId_,
        uint16 dstChainId_,
        bytes memory message_,
        bytes memory extraData_
    ) internal {
        IAmbImplementation ambImplementation = amb[ambId_];

        if (address(ambImplementation) == address(0)) {
            revert INVALID_BRIDGE_ID();
        }

        ambImplementation.dispatchPayload{value: msg.value / 2}(
            dstChainId_,
            message_,
            extraData_
        );
    }

    function _dispatchProof(
        uint8 ambId_,
        uint8[] memory secAmbId_,
        uint16 dstChainId_,
        bytes memory message_,
        bytes memory extraData_
    ) internal {
        /// @dev generates the proof
        bytes memory proof = abi.encode(keccak256(message_));

        AMBMessage memory data = abi.decode(message_, (AMBMessage));
        data.params = proof;

        for (uint8 i = 0; i < secAmbId_.length; i++) {
            uint8 tempAmbId = secAmbId_[i];

            if (tempAmbId == ambId_) {
                revert INVALID_PROOF_BRIDGE_ID();
            }

            IAmbImplementation tempImpl = amb[tempAmbId];

            if (address(tempImpl) == address(0)) {
                revert INVALID_BRIDGE_ID();
            }

            /// @dev should figure out how to split message costs
            /// @notice for now works if the secAmbId loop lenght == 1
            tempImpl.dispatchPayload{value: msg.value / 2}(
                dstChainId_,
                abi.encode(data),
                extraData_
            );
        }
    }

    function _broadcastPayload(
        uint8 ambId_,
        bytes memory message_,
        bytes memory extraData_
    ) internal {
        IAmbImplementation ambImplementation = amb[ambId_];

        if (address(ambImplementation) == address(0)) {
            revert INVALID_BRIDGE_ID();
        }

        ambImplementation.broadcastPayload{value: msg.value / 2}(
            message_,
            extraData_
        );
    }

    function _broadcastProof(
        uint8 ambId_,
        uint8[] memory secAmbId_,
        bytes memory message_,
        bytes memory extraData_
    ) internal {
        /// @dev generates the proof
        bytes memory proof = abi.encode(keccak256(message_));

        AMBFactoryMessage memory data = abi.decode(
            message_,
            (AMBFactoryMessage)
        );
        AMBMessage memory newData = AMBMessage(data.superFormId, proof);

        for (uint8 i = 0; i < secAmbId_.length; i++) {
            uint8 tempAmbId = secAmbId_[i];

            if (tempAmbId == ambId_) {
                revert INVALID_PROOF_BRIDGE_ID();
            }

            IAmbImplementation tempImpl = amb[tempAmbId];

            if (address(tempImpl) == address(0)) {
                revert INVALID_BRIDGE_ID();
            }

            /// @dev should figure out how to split message costs
            /// @notice for now works if the secAmbId loop lenght == 1
            tempImpl.broadcastPayload{value: msg.value / 2}(
                abi.encode(newData),
                extraData_
            );
        }
    }

    /// @dev PREVILEGED admin ONLY FUNCTION.
    /// @param superRegistry_    represents the address of the superRegistry
    function setSuperRegistry(
        address superRegistry_
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        superRegistry = ISuperRegistry(superRegistry_);

        emit SuperRegistryUpdated(superRegistry_);
    }
}