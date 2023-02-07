// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/ErcMassTransferer.sol";
import {console2} from "forge-std/console2.sol";

contract MassTransfererTest is Test {
    using SafeERC20 for IERC20EXT;

    address private TOKEN_USDT_CONTRACT_ADDR = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private TOKEN_USDT_HOLDER_ADDR = 0x5754284f345afc66a98fbB0a0Afe71e0F007B949;

    address private TOKEN_USDC_CONTRACT_ADDR = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private TOKEN_USDC_HOLDER_ADDR = 0x0A59649758aa4d66E25f08Dd01271e891fe52199;

    MassTransferer public mass_transferer;
    IERC20EXT usdt = IERC20EXT(TOKEN_USDT_CONTRACT_ADDR);
    IERC20EXT usdc = IERC20EXT(TOKEN_USDC_CONTRACT_ADDR);

    address mass_transferer_owner = vm.addr(0x1);
    address user = vm.addr(0x2);

    uint256 userInitBalance = 10000000e6;
    uint256[] values;
    address[] recipients;
    uint256 totalValue = 0;

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("ALCHEMY_ETH_MAINNET_RPC_URL"));
        vm.selectFork(fork);
        // console.log("Preparing values and recipients arrays");
        for (uint256 i = 1; i < 10; i++) {
            uint256 currentValue = (i * 100);
            values.push(currentValue);
            totalValue += currentValue;
            address rec = vm.addr(i + 10);
            vm.label(rec, string.concat("recipient #", vm.toString(i)));
            recipients.push(rec);
        }

        vm.label(TOKEN_USDT_CONTRACT_ADDR, "Tether USD");
        vm.label(TOKEN_USDT_HOLDER_ADDR, "usdt holder");
        vm.label(TOKEN_USDC_CONTRACT_ADDR, "USD Coin");
        vm.label(TOKEN_USDC_HOLDER_ADDR, "usdc holder");
        vm.label(user, "User");

        vm.startPrank(mass_transferer_owner);
        mass_transferer = new MassTransferer();
        mass_transferer.unpause();
        vm.stopPrank();

        // console.log("Transfering USDT to main user");
        vm.startPrank(TOKEN_USDT_HOLDER_ADDR);
        usdt.safeTransfer(user, userInitBalance);
        vm.stopPrank();

        // console.log("Transfering USDC to main user");
        vm.startPrank(TOKEN_USDC_HOLDER_ADDR);
        usdc.safeTransfer(user, userInitBalance);
        vm.stopPrank();
    }

    event MassTransferComplete(address indexed token, uint256 total);
    event Unpaused(address account);
    event Paused(address account);

    function test_setStopped_notOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        mass_transferer.setStopped(true);
    }

    function test_pause_notOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        mass_transferer.unpause();
    }

    function test_unpause_unpausedRevert() public {
        vm.startPrank(mass_transferer_owner);
        vm.expectRevert("Pausable: not paused");
        mass_transferer.unpause();
    }

    function test_pause_unpaused() public {
        vm.startPrank(mass_transferer_owner);
        address scAddr = address(mass_transferer);
        vm.expectEmit(true, true, true, true, scAddr);
        emit Paused(mass_transferer_owner);
        mass_transferer.pause();
        assertTrue(mass_transferer.paused());
        vm.expectEmit(true, true, true, true, scAddr);
        emit Unpaused(mass_transferer_owner);
        mass_transferer.unpause();
        assertFalse(mass_transferer.paused());
    }

    function test_setFee_notOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        mass_transferer.setFee(2);
    }

    function test_setFee() public {
        vm.startPrank(mass_transferer_owner);
        mass_transferer.setFee(123);
        assertEq(mass_transferer.getFee(), 123);
    }

    function test_getFee_and_noFeeAddDel() public {
        vm.startPrank(mass_transferer_owner);
        mass_transferer.setFee(0.001 ether);
        assertEq(mass_transferer.getFee(), 0.001 ether);
        mass_transferer.addNoFeeAddress(mass_transferer_owner);
        assertEq(mass_transferer.getFee(), 0);
        mass_transferer.delNoFeeAddress(mass_transferer_owner);
        assertEq(mass_transferer.getFee(), 0.001 ether);
        vm.stopPrank();
        assertEq(mass_transferer.getFee(), 0.001 ether);
    }

    function test_setMaxTransfersNumber_notOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        mass_transferer.setMaxTransfersNumber(2);
    }

    function test_setNewContract_notOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        mass_transferer.setNewContract("0x001");
    }

    function test_sendTokenUSDT_WhenPaused() public {
        vm.prank(mass_transferer_owner);
        mass_transferer.pause();
        vm.startPrank(user);
        vm.expectRevert("Pausable: paused");
        mass_transferer.sendToken(TOKEN_USDT_CONTRACT_ADDR, recipients, values);
        vm.stopPrank();
    }

    function test_sendTokenUSDT_WhenStopped() public {
        vm.prank(mass_transferer_owner);
        mass_transferer.setStopped(true);
        vm.startPrank(user);
        vm.expectRevert("Contract is stopped, new at: 0x0");
        mass_transferer.sendToken(TOKEN_USDT_CONTRACT_ADDR, recipients, values);
        vm.stopPrank();
    }

    function test_sendTokenUSDT_WhenStoppedNewAddress() public {
        vm.startPrank(mass_transferer_owner);
        mass_transferer.setStopped(true);
        mass_transferer.setNewContract("0x1");
        vm.stopPrank();
        vm.startPrank(user);
        vm.expectRevert("Contract is stopped, new at: 0x1");
        mass_transferer.sendToken(TOKEN_USDT_CONTRACT_ADDR, recipients, values);
        vm.stopPrank();
    }

    function test_sendTokenUSDT_WrongArgsLength() public {
        vm.startPrank(user);
        uint256[] memory _values;
        vm.expectRevert("invalid recipient and amount arrays");
        mass_transferer.sendToken(TOKEN_USDT_CONTRACT_ADDR, recipients, _values);
        vm.stopPrank();
    }

    function test_sendTokenUSDT_ExceededTransfersNumber() public {
        vm.prank(mass_transferer_owner);
        mass_transferer.setMaxTransfersNumber(2);
        vm.startPrank(user);
        vm.expectRevert("max transfers number exceeded");
        mass_transferer.sendToken(TOKEN_USDT_CONTRACT_ADDR, recipients, values);
        vm.stopPrank();
    }

    function test_sendTokenUSDT_NoFeeProvided() public {
        vm.startPrank(user);
        vm.expectRevert("no fee provided");
        mass_transferer.sendToken(TOKEN_USDT_CONTRACT_ADDR, recipients, values);
        vm.stopPrank();
    }

    function test_sendTokenUSD_NoAllowance() public {
        vm.startPrank(user);
        uint256 feeValue = values.length * mass_transferer.getFee();
        vm.deal(user, feeValue);
        vm.expectRevert("not enough token allowance");
        mass_transferer.sendToken{value: feeValue}(TOKEN_USDT_CONTRACT_ADDR, recipients, values);
        vm.stopPrank();
    }

    function test_sendTokenUSD_NoBalance() public {
        vm.startPrank(user);
        address multisenderAddr = address(mass_transferer);
        usdt.safeTransfer(address(0x0), usdt.balanceOf(user) - totalValue + 100);
        usdt.safeApprove(multisenderAddr, totalValue);
        uint256 feeValue = values.length * mass_transferer.getFee();
        vm.deal(user, feeValue);
        vm.expectRevert("not enough token balance");
        mass_transferer.sendToken{value: feeValue}(TOKEN_USDT_CONTRACT_ADDR, recipients, values);
        vm.stopPrank();
    }

    function test_sendTokenUSDT_OK() public {
        vm.startPrank(user);
        address multisenderAddr = address(mass_transferer);
        assertEq(userInitBalance, usdt.balanceOf(user));
        usdt.safeApprove(multisenderAddr, totalValue);
        assertEq(usdt.allowance(user, multisenderAddr), totalValue);
        vm.expectEmit(true, true, false, true, multisenderAddr);
        emit MassTransferComplete(TOKEN_USDT_CONTRACT_ADDR, totalValue);
        uint256 feeValue = values.length * mass_transferer.getFee();
        vm.deal(user, feeValue);
        mass_transferer.sendToken{value: feeValue}(TOKEN_USDT_CONTRACT_ADDR, recipients, values);
        assertEq(usdt.allowance(user, multisenderAddr), 0);
        assertEq(address(mass_transferer).balance, feeValue);
        assertEq(usdt.balanceOf(user), userInitBalance - totalValue);
        vm.stopPrank();
    }

    function test_sendTokenUSDT_OK_NoFee() public {
        vm.prank(mass_transferer_owner);
        mass_transferer.addNoFeeAddress(user);
        vm.startPrank(user);
        address multisenderAddr = address(mass_transferer);
        assertEq(userInitBalance, usdt.balanceOf(user));
        usdt.safeApprove(multisenderAddr, totalValue);
        assertEq(usdt.allowance(user, multisenderAddr), totalValue);
        vm.expectEmit(true, true, false, true, multisenderAddr);
        emit MassTransferComplete(TOKEN_USDT_CONTRACT_ADDR, totalValue);
        mass_transferer.sendToken(TOKEN_USDT_CONTRACT_ADDR, recipients, values);
        assertEq(usdt.allowance(user, multisenderAddr), 0);
        assertEq(address(mass_transferer).balance, 0);
        assertEq(usdt.balanceOf(user), userInitBalance - totalValue);
        vm.stopPrank();
    }

    function test_sendMain_whenStopped() public {
        vm.prank(mass_transferer_owner);
        mass_transferer.setStopped(true);
        vm.startPrank(user);
        vm.expectRevert("Contract is stopped, new at: 0x0");
        mass_transferer.sendMain(recipients, values);
        vm.stopPrank();
    }

    function test_sendMain_WhenPaused() public {
        vm.prank(mass_transferer_owner);
        mass_transferer.pause();
        vm.startPrank(user);
        vm.expectRevert("Pausable: paused");
        mass_transferer.sendMain(recipients, values);
        vm.stopPrank();
    }

    function test_sendMain_WrongArgsLength() public {
        vm.startPrank(user);
        uint256[] memory _values;
        vm.expectRevert("invalid recipient and amount arrays");
        mass_transferer.sendMain(recipients, _values);
        vm.stopPrank();
    }

    function test_sendMain_ExceededTransfersNumber() public {
        vm.prank(mass_transferer_owner);
        mass_transferer.setMaxTransfersNumber(2);
        vm.startPrank(user);
        vm.expectRevert("max transfers number exceeded");
        mass_transferer.sendMain(recipients, values);
        vm.stopPrank();
    }

    function test_sendMain_NoFeeProvided() public {
        vm.startPrank(user);
        vm.expectRevert("no fee provided");
        mass_transferer.sendMain(recipients, values);
        vm.stopPrank();
    }

    function test_sendMain_NoValue() public {
        vm.startPrank(user);
        uint256 feeValue = values.length * mass_transferer.getFee();
        vm.deal(user, feeValue);
        vm.expectRevert("not enough value");
        mass_transferer.sendMain{value: feeValue}(recipients, values);
        vm.stopPrank();
    }

    function test_sendMain_OK() public {
        vm.startPrank(user);
        uint256 feeValue = values.length * mass_transferer.getFee();
        uint256 neededValue = feeValue + totalValue;
        vm.deal(user, neededValue);
        mass_transferer.sendMain{value: neededValue}(recipients, values);
        assertEq(address(mass_transferer).balance, feeValue);
        assertEq(address(recipients[2]).balance, values[2]);
        vm.stopPrank();
    }

    function test_sendMain_OK_NoFee() public {
        vm.prank(mass_transferer_owner);
        mass_transferer.addNoFeeAddress(user);
        vm.startPrank(user);
        uint256 feeValue = values.length * mass_transferer.getFee();
        uint256 neededValue = feeValue + totalValue;
        vm.deal(user, neededValue);
        mass_transferer.sendMain{value: neededValue}(recipients, values);
        assertEq(address(mass_transferer).balance, 0);
        assertEq(address(recipients[2]).balance, values[2]);
        vm.stopPrank();
    }

    function test_withdraw_notOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.deal(address(mass_transferer), 100 ether);
        mass_transferer.withdraw();
    }

    function test_Withdraw_zeroBalance() public {
        vm.expectRevert("zero balance");
        vm.prank(mass_transferer_owner);
        mass_transferer.withdraw();
    }

    function test_withdraw_OK() public {
        vm.prank(mass_transferer_owner);
        vm.deal(address(mass_transferer), 100 ether);
        mass_transferer.withdraw();
        assertEq(mass_transferer.owner().balance, 100 ether);
    }

    function test_withdrawToken_notOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        mass_transferer.withdrawToken(usdt);
    }

    function test_withdrawToken_zeroBalance() public {
        vm.expectRevert("zero balance");
        vm.prank(mass_transferer_owner);
        mass_transferer.withdrawToken(usdt);
    }

    function test_withdrawToken_OK() public {
        vm.prank(TOKEN_USDT_HOLDER_ADDR);
        usdt.safeTransfer(address(mass_transferer), 1000e6);

        assertEq(usdt.balanceOf(mass_transferer_owner), 0);
        vm.prank(mass_transferer_owner);
        mass_transferer.withdrawToken(usdt);
        assertEq(usdt.balanceOf(mass_transferer_owner), 1000e6);
    }
}
