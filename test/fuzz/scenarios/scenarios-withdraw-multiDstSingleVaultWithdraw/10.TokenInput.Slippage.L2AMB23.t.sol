/// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

// Test Utils
import "../../../utils/ProtocolActions.sol";

contract MDSVW10NativeSlippageL2AMB23 is ProtocolActions {
    function setUp() public override {
        super.setUp();
        /*//////////////////////////////////////////////////////////////
                !! WARNING !!  DEFINE TEST SETTINGS HERE
    //////////////////////////////////////////////////////////////*/
        AMBs = [2, 3];
        MultiDstAMBs = [AMBs, AMBs];

        CHAIN_0 = AVAX;
        DST_CHAINS = [OP, ARBI];

        /// @dev define vaults amounts and slippage for every destination chain and for every action
        TARGET_UNDERLYINGS[OP][0] = [2];
        TARGET_UNDERLYINGS[ARBI][0] = [1];

        TARGET_VAULTS[OP][0] = [1];

        /// @dev id 0 is normal 4626
        TARGET_VAULTS[ARBI][0] = [0];
        /// @dev id 0 is normal 4626

        TARGET_FORM_KINDS[OP][0] = [1];
        TARGET_FORM_KINDS[ARBI][0] = [0];

        /// @dev define vaults amounts and slippage for every destination chain and for every action
        TARGET_UNDERLYINGS[OP][1] = [2];
        TARGET_UNDERLYINGS[ARBI][1] = [1];

        TARGET_VAULTS[OP][1] = [1];

        /// @dev id 0 is normal 4626
        TARGET_VAULTS[ARBI][1] = [0];
        /// @dev id 0 is normal 4626

        TARGET_FORM_KINDS[OP][1] = [1];
        TARGET_FORM_KINDS[ARBI][1] = [0];

        MAX_SLIPPAGE = 1000;

        /// @dev 1 for socket, 2 for lifi
        LIQ_BRIDGES[OP][0] = [2];
        LIQ_BRIDGES[OP][1] = [2];

        LIQ_BRIDGES[ARBI][0] = [2];
        LIQ_BRIDGES[ARBI][1] = [2];

        actions.push(
            TestAction({
                action: Actions.Deposit,
                multiVaults: false, //!!WARNING turn on or off multi vaults
                user: 0,
                testType: TestType.Pass,
                revertError: "",
                revertRole: "",
                slippage: 124, // 0% <- if we are testing a pass this must be below each maxSlippage,
                multiTx: false,
                externalToken: 2 // 0 = DAI, 1 = USDT, 2 = WETH
             })
        );

        actions.push(
            TestAction({
                action: Actions.Withdraw,
                multiVaults: false, //!!WARNING turn on or off multi vaults
                user: 0,
                testType: TestType.Pass,
                revertError: "",
                revertRole: "",
                slippage: 124, // 0% <- if we are testing a pass this must be below each maxSlippage,
                multiTx: false,
                externalToken: 1 // 0 = DAI, 1 = USDT, 2 = WETH
             })
        );
    }

    /*///////////////////////////////////////////////////////////////
                        SCENARIO TESTS
    //////////////////////////////////////////////////////////////*/

    function test_scenario(uint128 amountOne_, uint128 amountTwo_) public {
        /// @dev amount = 1 after slippage will become 0, hence starting with 2
        amountOne_ = uint128(bound(amountOne_, 2, TOTAL_SUPPLY_WETH / 2));
        amountTwo_ = uint128(bound(amountTwo_, 2, TOTAL_SUPPLY_WETH / 2));

        AMOUNTS[OP][0] = [amountOne_];
        AMOUNTS[OP][1] = [amountOne_];

        AMOUNTS[ARBI][0] = [amountTwo_];
        AMOUNTS[ARBI][1] = [amountTwo_];

        for (uint256 act = 0; act < actions.length; act++) {
            TestAction memory action = actions[act];
            MultiVaultSFData[] memory multiSuperformsData;
            SingleVaultSFData[] memory singleSuperformsData;
            MessagingAssertVars[] memory aV;
            StagesLocalVars memory vars;
            bool success;

            _runMainStages(action, act, multiSuperformsData, singleSuperformsData, aV, vars, success);
        }
    }
}