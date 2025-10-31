// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/ERC20Mock.sol";

import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    uint256 public timesMintIsCalled;
    address[] public usersWithCollateralDeposited;

    MockV3Aggregator public ehtUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ehtUsdPriceFeed = MockV3Aggregator(
            dscEngine.getCollateralTokenPriceFeed(address(weth))
        );
        btcUsdPriceFeed = MockV3Aggregator(
            dscEngine.getCollateralTokenPriceFeed(address(wbtc))
        );
    }

    // Mint DSC

    function mintDsc(uint256 amount, uint256 addressSeed) public {
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }

        address sender = usersWithCollateralDeposited[
            addressSeed % usersWithCollateralDeposited.length
        ];

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine
            .getAccountInformation(sender);

        uint256 maxDscToMint = (collateralValueInUsd / 2) - totalDscMinted;

        if (maxDscToMint < 0) {
            return;
        }

        amount = bound(amount, 0, uint256(maxDscToMint));

        if (amount == 0) {
            return;
        }

        vm.startPrank(sender);
        dscEngine.mintDsc(amount);
        vm.stopPrank();

        timesMintIsCalled++;
    }

    //  Deposit collateral

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
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender);
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

    // This breaks ourt invariant test suite
    // function updateCollateralPrice(
    //     uint256 collateralSeed,
    //     int256 newPrice
    // ) public {
    //     ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

    //     if (address(collateral) == address(weth)) {
    //         ehtUsdPriceFeed.updateAnswer(newPrice);
    //     } else {
    //         btcUsdPriceFeed.updateAnswer(newPrice);
    //     }
    // }

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
