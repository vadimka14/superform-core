///SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;
import {AccessControl} from "@openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {TransactionType, CallbackType, AMBMessage, InitSingleVaultData, InitMultiVaultData, ReturnMultiData, ReturnSingleData} from "./types/DataTypes.sol";
import {LiqRequest} from "./types/DataTypes.sol";
import {IBaseStateRegistry} from "./interfaces/IBaseStateRegistry.sol";
import {ISuperRegistry} from "./interfaces/ISuperRegistry.sol";
import {IBaseForm} from "./interfaces/IBaseForm.sol";
import {ITokenBank} from "./interfaces/ITokenBank.sol";
import "./utils/DataPacking.sol";
import "forge-std/console.sol";

/// @title Token Bank
/// @author Zeropoint Labs.
/// @dev Temporary area for underlying tokens to wait until they are ready to be sent to the form vault
contract TokenBank is ITokenBank, AccessControl {
    using SafeTransferLib for ERC20;

    /*///////////////////////////////////////////////////////////////
                    Access Control Role Constants
    //////////////////////////////////////////////////////////////*/
    bytes32 public constant STATE_REGISTRY_ROLE =
        keccak256("STATE_REGISTRY_ROLE");

    /*///////////////////////////////////////////////////////////////
                    State Variables
    //////////////////////////////////////////////////////////////*/

    /// @dev safeGasParam is used while sending layerzero message from destination to router.
    bytes public safeGasParam;

    /// @dev superRegistry points to the super registry deployed in the respective chain.
    ISuperRegistry public superRegistry;

    /// @dev chainId represents the superform chain id of the specific chain.
    uint16 public immutable chainId;

    /// @notice deploy stateRegistry before SuperDestination
    /// @param chainId_              Superform chain id
    /// @dev sets caller as the admin of the contract.
    constructor(uint16 chainId_) {
        if (chainId_ == 0) revert INVALID_INPUT_CHAIN_ID();

        chainId = chainId_;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /*///////////////////////////////////////////////////////////////
                        External Write Functions
    //////////////////////////////////////////////////////////////*/
    receive() external payable {}

    /// @dev handles the state when received from the source chain.
    /// @param multiVaultData_     represents the struct with the associated multi vault data
    /// note: called by external keepers when state is ready.
    /// note: state registry sorts by deposit/withdraw txType before calling this function.
    function depositMultiSync(
        InitMultiVaultData memory multiVaultData_
    ) external payable override onlyRole(STATE_REGISTRY_ROLE) {
        (
            address[] memory superForms,
            uint256[] memory formIds,

        ) = _getSuperForms(multiVaultData_.superFormIds);
        ERC20 underlying;
        uint256[] memory dstAmounts = new uint256[](
            multiVaultData_.superFormIds.length
        );

        for (uint256 i = 0; i < multiVaultData_.superFormIds.length; i++) {
            /// @dev FIXME: whole msg.value is transferred here, in multi sync this needs to be split

            underlying = IBaseForm(superForms[i]).getUnderlyingOfVault();

            /// @dev This will revert ALL of the transactions if one of them fails.
            if (
                underlying.balanceOf(address(this)) >=
                multiVaultData_.amounts[i]
            ) {
                underlying.transfer(superForms[i], multiVaultData_.amounts[i]);
                LiqRequest memory emptyRequest;

                dstAmounts[i] = IBaseForm(superForms[i]).xChainDepositIntoVault(
                    InitSingleVaultData({
                        txData: multiVaultData_.txData,
                        superFormId: multiVaultData_.superFormIds[i],
                        amount: multiVaultData_.amounts[i],
                        maxSlippage: multiVaultData_.maxSlippage[i],
                        liqData: emptyRequest,
                        extraFormData: multiVaultData_.extraFormData
                    })
                );
            } else {
                revert BRIDGE_TOKENS_PENDING();
            }
        }

        (, uint16 srcChainId, uint80 currentTotalTxs) = _decodeTxData(
            multiVaultData_.txData
        );

        /// @dev FIXME HARDCODED FIX AMBMESSAGE TO HAVE THIS AND THE PRIMARY AMBID
        uint8[] memory proofAmbIds = new uint8[](1);
        proofAmbIds[0] = 2;

        /// @notice Send Data to Source to issue superform positions.
        IBaseStateRegistry(superRegistry.coreStateRegistry()).dispatchPayload{
            value: msg.value
        }(
            1, /// @dev come to this later to accept any bridge id
            proofAmbIds,
            srcChainId,
            abi.encode(
                AMBMessage(
                    _packTxInfo(
                        uint120(TransactionType.DEPOSIT),
                        uint120(CallbackType.RETURN),
                        true,
                        0
                    ),
                    abi.encode(
                        ReturnMultiData(
                            _packReturnTxInfo(
                                true,
                                srcChainId,
                                chainId,
                                currentTotalTxs
                            ),
                            dstAmounts
                        )
                    )
                )
            ),
            safeGasParam
        );
    }

    /// @dev handles the state when received from the source chain.
    /// @param singleVaultData_       represents the struct with the associated single vault data
    /// note: called by external keepers when state is ready.
    /// note: state registry sorts by deposit/withdraw txType before calling this function.
    function depositSync(
        InitSingleVaultData memory singleVaultData_
    ) external payable override onlyRole(STATE_REGISTRY_ROLE) {
        (address superForm_, uint256 formId_, ) = _getSuperForm(
            singleVaultData_.superFormId
        );
        ERC20 underlying = IBaseForm(superForm_).getUnderlyingOfVault();
        uint256 dstAmount;
        /// @dev This will revert ALL of the transactions if one of them fails.

        /// DEVNOTE: This will revert with an error only descriptive of the first possible revert out of many
        /// 1. Not enough tokens on this contract == BRIDGE_TOKENS_PENDING
        /// 2. Fail to .transfer() == BRIDGE_TOKENS_PENDING
        /// 3. xChainDepositIntoVault() reverting on anything == BRIDGE_TOKENS_PENDING
        /// FIXME: Add reverts at the Form level
        if (underlying.balanceOf(address(this)) >= singleVaultData_.amount) {
            underlying.transfer(superForm_, singleVaultData_.amount);

            dstAmount = IBaseForm(superForm_).xChainDepositIntoVault(
                singleVaultData_
            );
        } else {
            revert BRIDGE_TOKENS_PENDING();
        }

        (, uint16 srcChainId, uint80 currentTotalTxs) = _decodeTxData(
            singleVaultData_.txData
        );

        /// @dev FIXME HARDCODED FIX AMBMESSAGE TO HAVE THIS AND THE PRIMARY AMBID
        uint8[] memory proofAmbIds = new uint8[](1);
        proofAmbIds[0] = 2;

        /// @notice Send Data to Source to issue superform positions.
        IBaseStateRegistry(superRegistry.coreStateRegistry()).dispatchPayload{
            value: msg.value
        }(
            1, /// @dev come to this later to accept any bridge id
            proofAmbIds,
            srcChainId,
            abi.encode(
                AMBMessage(
                    _packTxInfo(
                        uint120(TransactionType.DEPOSIT),
                        uint120(CallbackType.RETURN),
                        false,
                        0
                    ),
                    abi.encode(
                        ReturnSingleData(
                            _packReturnTxInfo(
                                true,
                                srcChainId,
                                chainId,
                                currentTotalTxs
                            ),
                            dstAmount
                        )
                    )
                )
            ),
            safeGasParam
        );
    }

    /// @dev handles the state when received from the source chain.
    /// @param multiVaultData_       represents the struct with the associated multi vault data
    /// note: called by external keepers when state is ready.
    /// note: state registry sorts by deposit/withdraw txType before calling this function.
    function withdrawMultiSync(
        InitMultiVaultData memory multiVaultData_
    ) external payable override onlyRole(STATE_REGISTRY_ROLE) {
        /// @dev This will revert ALL of the transactions if one of them fails.
        for (uint256 i = 0; i < multiVaultData_.superFormIds.length; i++) {
            withdrawSync(
                InitSingleVaultData({
                    txData: multiVaultData_.txData,
                    superFormId: multiVaultData_.superFormIds[i],
                    amount: multiVaultData_.amounts[i],
                    maxSlippage: multiVaultData_.maxSlippage[i],
                    liqData: multiVaultData_.liqData[i],
                    extraFormData: multiVaultData_.extraFormData
                })
            );
        }
    }

    /// @dev handles the state when received from the source chain.
    /// @param singleVaultData_       represents the struct with the associated single vault data
    /// note: called by external keepers when state is ready.
    /// note: state registry sorts by deposit/withdraw txType before calling this function.
    function withdrawSync(
        InitSingleVaultData memory singleVaultData_
    ) public payable override onlyRole(STATE_REGISTRY_ROLE) {
        (address superForm_, uint256 formId_, ) = _getSuperForm(
            singleVaultData_.superFormId
        );

        IBaseForm(superForm_).xChainWithdrawFromVault(singleVaultData_);
    }

    /// @dev PREVILEGED admin ONLY FUNCTION.
    /// @dev adds the gas overrides for layerzero.
    /// @param param_    represents adapterParams V2.0 of layerzero
    function updateSafeGasParam(
        bytes memory param_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (param_.length == 0) revert INVALID_GAS_OVERRIDE();
        bytes memory oldParam = safeGasParam;
        safeGasParam = param_;

        emit SafeGasParamUpdated(oldParam, param_);
    }

    /// @dev PREVILEGED admin ONLY FUNCTION.
    /// @param superRegistry_    represents the address of the superRegistry
    function setSuperRegistry(
        address superRegistry_
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address(superRegistry_) == address(0)) {
            revert ZERO_ADDRESS();
        }
        superRegistry = ISuperRegistry(superRegistry_);

        emit SuperRegistryUpdated(superRegistry_);
    }
}