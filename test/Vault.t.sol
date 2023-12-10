// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Vault, VaultEvents, VaultErrors} from "../src/Vaults/Vault.sol";
import {MockStrategy} from "./helpers/MockStrategy.sol";
import {ERC20Mock} from "oz/mocks/token/ERC20Mock.sol";

///@dev Testing assumptions are placed out in order to help evaluate the potential
/// paths that a particular function could follow. Set up to be similar to a testing tree
/// its intention is to help increase coverage and path testing.

/**
 * Testing Todo:
 *     1. Open Role
 *     2. Close Roles
 *     3. DepositLimit
 *     4. Accountant
 *     5. Set Default Queue
 *     6. Set Depoist Limit Module
 *     7. Set Withdraw Limit Module
 *     8. Set Min total Idle
 *     9. Set Profit Unlock Time
 *     10. Increase Allowance
 *     11. Decrease Allowance
 *     12. Redeem
 *     13. Withdraw
 *     14. Add Strategy
 *     15. Revoke Strategy
 *     16. Force Revoke Strategy
 *     17. Shutdown Vault
 *     18. Update Debt
 *     19. Update max debt for strategy
 */

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
     * Test the transfer and acceptance of the role manager
     *     Testing Assumptions:
     */
    function testRoleManagerTransfer(address y) public {
        vm.assume(y != vault.roleManager());
        vm.prank(y);
        vm.expectRevert(VaultErrors.OnlyManager.selector);
        vault.transferRoleManger(y);

        vault.transferRoleManger(y);

        vm.expectRevert(VaultErrors.OnlyManager.selector);
        vault.acceptRoleManager();

        vm.prank(y);
        vault.acceptRoleManager();

        assertEq(vault.roleManager(), y);
    }

    /**
     * Testing Assumptions:
     *     Case 1: The caller is the role manager
     *         1. The input address should be given the given role
     *     Case 2: The caller is not the role manager
     *         1. The call should revert with the OnlyManager Error
     */
    function testSetRole(address y, address x) public {
        vm.assume(x != vault.roleManager());
        vault.setRole(y, VaultEvents.Roles.DEPOSIT_LIMIT_MANAGER);
        assertEq(vault.roles(y, VaultEvents.Roles.DEPOSIT_LIMIT_MANAGER), true);

        vm.prank(x);
        vm.expectRevert(VaultErrors.OnlyManager.selector);
        vault.setRole(y, VaultEvents.Roles.DEBT_MANAGER);
        assertEq(vault.roles(y, VaultEvents.Roles.DEBT_MANAGER), false);
    }

    /**
     * Testing Assumptions:
     *     Case 1: The caller is the role manager
     *             1. The call will not revert and the role will be set to false for the user
     *     Case 2: The caller is not the role manager;
     *             1. The call will revert.
     */
    function testRevokeRoles(address y, address pranker) public {
        vm.assume(pranker != vault.roleManager());
        vault.setRole(y, VaultEvents.Roles.ACCOUNTANT_MANAGER);
        assertEq(vault.roles(y, VaultEvents.Roles.ACCOUNTANT_MANAGER), true);

        vm.prank(pranker);
        vm.expectRevert(VaultErrors.OnlyManager.selector);
        vault.removeRole(y, VaultEvents.Roles.ACCOUNTANT_MANAGER);
        assertEq(vault.roles(y, VaultEvents.Roles.ACCOUNTANT_MANAGER), true);

        vault.removeRole(y, VaultEvents.Roles.ACCOUNTANT_MANAGER);
        assertEq(vault.roles(y, VaultEvents.Roles.ACCOUNTANT_MANAGER), false);
    }

    function testOpenRole() public {}

    function testCloseRole() public {}

    /**
     * Testing Assumptions:
     *         Case 1: The caller has the role and the strategy is not activated
     *         Case 2: The caller does not have the role and the strategy is not activated
     *         Case 3: The caller has the role but the strategy is not activated
     *         Case 4: The caller does not have the role and the strategy is not activated
     *         Case 5: The address of the strategy input is address(0) || vault address
     *         Case 6: The strategy is valid and the caller has the role and the default queue is not full
     *         Caes 7: The strategy is valid and the caller has the role and the default queue is full
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
    function testTransferFrom(uint256 x) public {
        //Case 1
        vm.assume(x > 0 && x < 10_000_000 ether);
        mock.approve(address(vault), type(uint256).max);
        vault.mint(10_000_000 ether, address(this));
        vm.prank(alice);
        vm.expectRevert(VaultErrors.InsufficentAllowance.selector);
        vault.transferFrom(address(this), alice, x);
        assertEq(vault.balanceOf(address(this)), 10_000_000 ether);
        assertEq(vault.balanceOf(alice), 0);

        //Case 2
        vault.approve(alice, x);
        assertEq(vault.allowance(address(this), alice), x);
        vm.prank(alice);
        vault.transferFrom(address(this), alice, x);
        assertEq(vault.balanceOf(address(this)), 10_000_000 ether - x);
        assertEq(vault.balanceOf(alice), x);
        assertEq(vault.allowance(address(this), alice), 0);

        //Case 3
        vault.approve(alice, type(uint128).max);
        uint256 ownerPre = vault.balanceOf(address(this));
        uint256 alicePre = vault.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert(VaultErrors.InsufficentBalance.selector);
        vault.transferFrom(address(this), alice, 10_000_000 ether);
        assertEq(vault.balanceOf(address(this)), ownerPre);
        assertEq(vault.balanceOf(alice), alicePre);
        assertEq(vault.allowance(address(this), alice), type(uint128).max);

        //Case 4
        vault.approve(alice, 100);
        vm.prank(alice);
        vm.expectRevert(VaultErrors.InsufficentAllowance.selector);
        vault.transferFrom(address(this), alice, 10_000_000 ether);
        assertEq(vault.balanceOf(address(this)), ownerPre);
        assertEq(vault.balanceOf(alice), alicePre);
        assertEq(vault.allowance(address(this), alice), 100);

        //Case 5 A
        vault.approve(alice, type(uint128).max);
        vm.prank(alice);
        vm.expectRevert(VaultErrors.InvalidTransfer.selector);
        vault.transferFrom(address(this), address(vault), ownerPre);
        assertEq(vault.balanceOf(address(this)), ownerPre);
        assertEq(vault.balanceOf(alice), alicePre);
        assertEq(vault.allowance(address(this), alice), type(uint128).max);

        //Case 5 B
        vault.approve(alice, type(uint128).max);
        vm.prank(alice);
        vm.expectRevert(VaultErrors.InvalidTransfer.selector);
        vault.transferFrom(address(this), address(0), ownerPre);
        assertEq(vault.balanceOf(address(this)), ownerPre);
        assertEq(vault.balanceOf(alice), alicePre);
        assertEq(vault.allowance(address(this), alice), type(uint128).max);
    }

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
