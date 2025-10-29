// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Test, console } from "forge-std/Test.sol";

import { DeployDSC } from "../../script/DeployDSC.s.sol";

import { DecentralizedStableCoin } from "../../src/DecentralizedStableCoin.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;

    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    HelperConfig config;

    address ethUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();

        (dsc, dscEngine, config) = deployer.run();
        (ethUsdPriceFeed,, weth,,) = config.activeNetworkConfig();

        vm.deal(USER, 10 ether);

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ////////////////////
    // Constructor Test
    ////////////////////

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        address[] memory priceFeeds = new address[](1);
        address[] memory tokens = new address[](2);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(priceFeeds, tokens, address(dsc));
    }

    ////////////////////
    // Price Test
    ////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18; // == 15 ether

        uint256 expectedUsd = 30_000e18;
        uint256 actualUsd = dscEngine.getUsdValue(address(weth), ethAmount);

        assertEq(expectedUsd, actualUsd);
    }

    function testgetTokenAmountFromUsd() public {
        uint256 usdAmount = 30_000e18; // $30,000

        uint256 expectedWeth = 15e18; // == 15 ether
        uint256 actualWeth = dscEngine.getTokenAmountFromUsd(address(weth), usdAmount);

        assertEq(expectedWeth, actualWeth);
    }

    //////////////////////////
    // DepositCollateral Test
    //////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
    }

    function testRevertsIfUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RANT", "RANtoken", USER, AMOUNT_COLLATERAL);

        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dscEngine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedCollateralValueInUsd = dscEngine.getUsdValue(address(weth), AMOUNT_COLLATERAL);

        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(collateralValueInUsd, expectedCollateralValueInUsd);
    }
}
