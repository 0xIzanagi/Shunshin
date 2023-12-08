// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Vault, VaultEvents, VaultErrors} from "../src/Vaults/Vault.sol";
import {ERC20Mock} from "oz/mocks/token/ERC20Mock.sol";

///@dev Testing assumptions are placed out in order to help evaluate the potential 
/// paths that a particular function could follow. Set up to be similar to a testing tree
/// its intention is to help increase coverage and path testing. 

contract VaultTest is Test {
    ERC20Mock public mock;
    Vault public vault;
    address public alice = address(0x01);

    function setUp() public {
        mock = new ERC20Mock();
        vault = new Vault(mock, "MockVault", "MCKV", address(this), 1_000_000);
        mock.mint(address(this), 10_000_000 ether);
        vault.setRole(address(this), VaultEvents.Roles.DEPOSIT_LIMIT_MANAGER);
        vault.setDepositLimit(100_000_000 ether);
    }

    /**
     * Testing Assumptions:
     *         1. The caller grants the stated amount to the user
     *         2. No other state is effected besides the caller -> spender allowance mapping
     *         3. If successful it will return true
     */
    function testApprove(uint256 x, address y) public {
        bool result = vault.approve(y, x);
        assertEq(result, true);
        assertEq(vault.allowance(address(this), y), x);
    }

    /**
     * Testing Assumptions:
     *         Case 1: The Caller has the necessary role
     *         Case 2: The caller does not have the necessary role
     *         Case 3: Case 1 + The address for the strategy is address(0) | address(vault)
     *         Case 4: Case 1 + the strategy asset is not the same
     *         Case 5: Case 1 + The asset is the same
     *         Case 6: Case 1 + the strategy has not already been activiated
     *         Case 7: Case 1 + the strategy has already been activiated.
     */
    function testAddStrategy() public {}

    /**
     * Testing Assumptions:
     *     Case 1: The user has the required role
     *     Case 2: The user does not have the required role and it is not an open role
     *     Case 3: The strategy has debt, but forces a shutdown of the strategy
     *     Case 4: The strategy does not currently have debt. 
     *     Case 5: 3 + it does not force a shutdown.
     */
    function testRevokeStrategy() public {}

    /**
     * Testing Assumptions
     *     Case 1. The user has enough tokens to transfer
     *         1. The Senders balance should decrease by an equivilant amount
     *         2. The receivers balance should increase by the sent amount
     *         3. No one elses balance should be effects
     *         4. The returned bool should be true;
     *         5. An event should be emitted
     *     Case 2. The users does not have enough tokens to sende
     *         1. The call should revert with the Insufficent Balance Error.
     *         2. The no one's balance should change
     *     Case 3. The users has enough tokens but the receiver is address 0 or the vault address
     *         1. The transfer call should fail and no ones balance should be effected.
     *         2. This should fail prior to checking the balance so even if sending 0 tokens
     *         the invalid transfer error should show first
     */
    function testTransfer(uint256 x, uint256 y) public {
        vm.assume(x > 0 && x < 10_000_000 ether);
        mock.approve(address(vault), type(uint256).max);
        vault.mint(x, address(this));
        uint256 pre = vault.balanceOf(address(this));
        vm.assume(y > 0 && y < pre);
        bool success = vault.transfer(alice, y);

        assertEq(success, true);
        assertEq(vault.balanceOf(alice), y);
        assertEq(vault.balanceOf(address(this)), pre - y);

        vm.expectRevert(VaultErrors.InsufficentBalance.selector);
        vault.transfer(alice, pre + y);

        vm.expectRevert(VaultErrors.InvalidTransfer.selector);
        vault.transfer(address(0), 0);

        vm.expectRevert(VaultErrors.InvalidTransfer.selector);
        vault.transfer(address(vault), 0);
    }

    /**
     * Testing Assumptions:
     *         Case 1: The user has enough tokens to transfer but have not approved
     *             1. The transfer should fail with the Insufficent Allowance Specification
     *             2. No balances should change.
     *             3. No allowances should change.
     *         Case 2. The user has enough tokens and has approved
     *             1. The transfer should succed and should return true
     *             2. The owners balance should decrease by an equivilant amount
     *             3. The receivers balance should increase by an equivilant amount
     *             4. The owners granted allowance to the caller should decrease by the amount of tokens sent
     *         Case 3: The user does not have enough tokens but has approved
     *             1. No balanes should change
     *             2. No allowances should change
     *             3. The call should revert with a Insufficent Balance Error
     *         Case 4: The user does not have enough tokens and has not approved
     *             1. No balanes should change
     *             2. No allowances should change
     *             3. The call should revert with a Insufficent Allowance Error
     *         Case 5: Receiver is address(0) or the vault address
     *             1. The call should not change any state and should revert with the Invalid Transfer Error
     */
    function testTransferFrom() public {}

    /**
     * Testing Assumptions:
     */

    function testDeposit(uint256 x) public {
        vm.assume(x > 0 && x < 10_000_000 ether);
        mock.approve(address(vault), type(uint256).max);
        uint256 amountOut = vault.deposit(x, address(this));
        assertEq(vault.balanceOf(address(this)), amountOut);
        assertEq(mock.balanceOf(address(vault)), x);
    }

    /**
     * Testing Assumptions:
     */

    function testMint(uint256 x) public {
        vm.assume(x > 0 && x < 10_000_000 ether);
        mock.approve(address(vault), type(uint256).max);
        uint256 amountOut = vault.mint(x, address(this));
        assertEq(vault.balanceOf(address(this)), amountOut);
        assertEq(mock.balanceOf(address(vault)), x);
    }

    // function testIncreaseAllowance() public {}

    // function testDecreaseAllowance() public {}

    // function testRedeem() public {}

    // function testWithdraw() public {}
}
