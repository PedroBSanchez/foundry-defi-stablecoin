// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/ERC20Mock.sol";

contract Handler is Test {
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    function depositCollateral(
        uint256 collateralSeed,
        uint256 ammountCollateral
    ) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        ammountCollateral = bound(ammountCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.approveInternal(
            msg.sender,
            address(dscEngine),
            MAX_DEPOSIT_SIZE
        );
        collateral.mint(msg.sender, ammountCollateral);
        dscEngine.depositCollateral(address(collateral), ammountCollateral);
    }

    // Redeem collateral

    function redeemCollateral(
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        uint256 userBalance = dscEngine.getUserCollateral(
            address(collateral),
            msg.sender
        );

        amountCollateral = bound(amountCollateral, 0, userBalance);

        if (amountCollateral == 0) {
            return;
        }

        vm.startPrank(msg.sender);
        dscEngine.redeemCollateral(address(collateral), amountCollateral);
    }

    // Helper functions

    function _getCollateralFromSeed(
        uint256 collateralSeed
    ) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
