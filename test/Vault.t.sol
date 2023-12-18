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

    function testSetDepositLimit(address x, uint256 y) public {
        vm.assume(x != address(this));
        vm.prank(x);
        vm.expectRevert(VaultErrors.OnlyRole.selector);
        vault.setDepositLimit(y);
        assertEq(vault.depositLimit(), 100_000_000 ether);

        vault.setRole(address(this), VaultEvents.Roles.DEPOSIT_LIMIT_MANAGER);
        vault.setDepositLimit(y);
        assertEq(vault.depositLimit(), y);
        vault.setDepositLimit(type(uint256).max);
        vault.setDepositLimitModule(address(0x01));
        vm.expectRevert(VaultErrors.UsingDepositModule.selector);
        vault.setDepositLimit(y);
    }

    function testMinTotalIdle(uint256 x, address y) public {
        vm.prank(y);
        vm.expectRevert(VaultErrors.OnlyRole.selector);
        vault.setMinimumTotalIdle(x);

        assertEq(vault.minimumTotalIdle(), 0);
        vault.setRole(address(this), VaultEvents.Roles.MINIMUM_IDLE_MANAGER);
        vault.setMinimumTotalIdle(x);
        assertEq(vault.minimumTotalIdle(), x);
    }

    function testSetWithdrawLimitModule(address y, address x) public {
        vm.prank(x);
        vm.expectRevert(VaultErrors.OnlyRole.selector);
        vault.setWithdrawLimitModule(y);

        assertEq(vault.withdrawLimitModule(), address(0));

        vault.setRole(address(this), VaultEvents.Roles.WITHDRAW_LIMIT_MANAGER);
        vault.setWithdrawLimitModule(y);
        assertEq(vault.withdrawLimitModule(), y);
    }

    function testSetDepositLimitModule(address y) public {
        vault.removeRole(address(this), VaultEvents.Roles.DEPOSIT_LIMIT_MANAGER);
        vm.expectRevert(VaultErrors.OnlyRole.selector);
        vault.setDepositLimitModule(y);
        assertEq(vault.depositLimitModule(), address(0));

        vault.setRole(address(this), VaultEvents.Roles.DEPOSIT_LIMIT_MANAGER);

        vm.expectRevert(VaultErrors.UsingDepositLimit.selector);
        vault.setDepositLimitModule(y);
        assertEq(vault.depositLimitModule(), address(0));

        vault.setDepositLimit(type(uint256).max);
        vault.setDepositLimitModule(y);
        assertEq(vault.depositLimitModule(), y);
    }

    function testSetAccountant(address y) public {
        vm.assume(y != address(this));
        vm.prank(y);
        vm.expectRevert(VaultErrors.OnlyRole.selector);
        vault.setAccountant(y);

        vault.setRole(address(this), VaultEvents.Roles.ACCOUNTANT_MANAGER);
        vault.setAccountant(y);
        assertEq(y, vault.accountant());
    }

    function testUseDefault(address y) public {
        vm.assume(y != address(this));
        vm.prank(y);
        vm.expectRevert(VaultErrors.OnlyRole.selector);
        vault.setUseDefaultQueue(true);
        assertEq(vault.useDefaultQueue(), false);

        vault.setRole(address(this), VaultEvents.Roles.QUEUE_MANAGER);
        vault.setUseDefaultQueue(true);
        assertEq(vault.useDefaultQueue(), true);
    }

    function testSetDefaultQueue() public {}

    //Note: Need to give the vaults profit shares to make sure if the profit unlock time is equal to 0 that it burns them and unlocks all the profit
    function testSetProfitMaxUnlockTime(address y, uint256 x) public {
        vm.prank(y);
        vm.expectRevert(VaultErrors.OnlyRole.selector);
        vault.setProfitMaxUnlockTime(x);

        vault.setRole(y, VaultEvents.Roles.PROFIT_UNLOCK_MANAGER);
        vm.startPrank(y);
        if (x > 31_556_952) {
            vm.expectRevert(VaultErrors.ProfitUnlockTime.selector);
            vault.setProfitMaxUnlockTime(x);
        } else if (x > 0) {
            vault.setProfitMaxUnlockTime(x);
            assertEq(vault.profitMaxUnlockTime(), x);
        } else if (x == 0) {
            vault.setProfitMaxUnlockTime(x);
            assertEq(vault.profitMaxUnlockTime(), 0);
            assertEq(vault.profitUnlockingRate(), 0);
            assertEq(vault.fullProfitUnlockDate(), 0);
        }
        vm.stopPrank();
    }

    function testSetMinTotalIdle(uint256 x, address y) public {
        vm.prank(y);
        vm.expectRevert(VaultErrors.OnlyRole.selector);
        vault.setMinimumTotalIdle(x);

        assertEq(vault.minimumTotalIdle(), 0);

        vault.setRole(y, VaultEvents.Roles.MINIMUM_IDLE_MANAGER);
        vm.prank(y);
        vault.setMinimumTotalIdle(x);
        assertEq(vault.minimumTotalIdle(), x);
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

    function testOpenRole(address y) public {
        vm.assume(y != vault.roleManager());
        vm.prank(y);
        vm.expectRevert(VaultErrors.OnlyManager.selector);
        vault.setOpenRole(VaultEvents.Roles.DEPOSIT_LIMIT_MANAGER);

        vault.setOpenRole(VaultEvents.Roles.DEPOSIT_LIMIT_MANAGER);
        assertEq(vault.openRoles(VaultEvents.Roles.DEPOSIT_LIMIT_MANAGER), true);
    }

    function testCloseRole(address y) public {
        vault.setOpenRole(VaultEvents.Roles.DEPOSIT_LIMIT_MANAGER);
        assertEq(vault.openRoles(VaultEvents.Roles.DEPOSIT_LIMIT_MANAGER), true);
        vm.assume(y != vault.roleManager());
        vm.prank(y);
        vm.expectRevert(VaultErrors.OnlyManager.selector);
        vault.closeOpenRole(VaultEvents.Roles.DEPOSIT_LIMIT_MANAGER);
        assertEq(vault.openRoles(VaultEvents.Roles.DEPOSIT_LIMIT_MANAGER), true);

        vault.closeOpenRole(VaultEvents.Roles.DEPOSIT_LIMIT_MANAGER);
        assertEq(vault.openRoles(VaultEvents.Roles.DEPOSIT_LIMIT_MANAGER), false);
    }

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
    function testAddStrategy(address y) public {
        MockStrategy _mock = new MockStrategy(address(mock));
        vm.prank(y);
        vm.expectRevert(VaultErrors.OnlyRole.selector);
        vault.addStrategy(address(_mock));

        vault.setRole(y, VaultEvents.Roles.ADD_STRATEGY_MANAGER);
        vm.startPrank(y);
        vm.expectRevert(VaultErrors.InvalidStrategy.selector);
        vault.addStrategy(address(0));
        vm.expectRevert(VaultErrors.InvalidStrategy.selector);
        vault.addStrategy(address(vault));

        vm.warp(100);
        vault.addStrategy(address(_mock));
        (uint256 activation, uint256 last, uint256 current, uint256 total) = vault.strategies(address(_mock));
        assertEq(activation, block.timestamp);
        assertEq(last, block.timestamp);
        assertEq(current, 0);
        assertEq(total, 0);

        vm.expectRevert(VaultErrors.ActiveStrategy.selector);
        vault.addStrategy(address(_mock));
        assertEq(vault.queueIndex(), 1);
        assertEq(vault.defaultQueue(0), address(_mock));
        vm.stopPrank();
    }

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
        vault.setDepositLimit(0);

        vm.expectRevert(VaultErrors.DepositLimit.selector);
        vault.deposit(x, address(this));

        vault.setDepositLimit(100_000_000 ether);
        uint256 amountOut = vault.deposit(x, address(this));
        assertEq(vault.balanceOf(address(this)), amountOut);
        assertEq(vault.totalSupply(), amountOut);
        assertEq(mock.balanceOf(address(vault)), x);
        assertEq(vault.totalIdle(), x);

        vm.expectRevert(VaultErrors.ZeroShares.selector);
        vault.deposit(0, address(this));

        vault.setRole(address(this), VaultEvents.Roles.EMERGENCY_MANAGER);
        vault.shutdownVault();
        vm.expectRevert(VaultErrors.VaultShutdown.selector);
        vault.deposit(x, address(this));
    }

    /**
     * Testing Assumptions:
     */

    function testMint(uint256 x) public {
        vm.assume(x > 0 && x < 10_000_000 ether);
        mock.approve(address(vault), type(uint256).max);

        vault.setDepositLimit(0);
        vm.expectRevert(VaultErrors.DepositLimit.selector);
        vault.mint(x, address(this));

        vault.setDepositLimit(100_000_000 ether);
        uint256 amountOut = vault.mint(x, address(this));
        assertEq(vault.balanceOf(address(this)), amountOut);
        assertEq(vault.totalSupply(), amountOut);
        assertEq(mock.balanceOf(address(vault)), x);
        assertEq(vault.totalIdle(), x);

        vm.expectRevert(VaultErrors.ZeroAssets.selector);
        vault.mint(0, address(this));

        vault.setRole(address(this), VaultEvents.Roles.EMERGENCY_MANAGER);
        vault.shutdownVault();
        vm.expectRevert(VaultErrors.VaultShutdown.selector);
        vault.mint(x, address(this));
    }

    function testIncreaseAllowance(uint256 x) public {
        vm.assume(x > 0 && x < type(uint64).max);
        assertEq(vault.allowance(address(this), alice), 0);
        vault.increaseAllowance(alice, x);
        assertEq(vault.allowance(address(this), alice), x);
        bool success = vault.increaseAllowance(alice, x);
        assertEq(success, true);
        assertEq(vault.allowance(address(this), alice), x * 2);
        vault.increaseAllowance(alice, x);
        assertEq(vault.allowance(address(this), alice), x * 3);
        vault.increaseAllowance(alice, x);
        assertEq(vault.allowance(address(this), alice), x * 4);
        vm.expectRevert();
        bool result = vault.increaseAllowance(alice, type(uint256).max);
        assertEq(result, false);
    }

    function testDecreaseAllowance(uint256 x) public {
        vm.assume(x > 0 && x < type(uint64).max);
        vault.approve(alice, type(uint256).max);
        assertEq(vault.allowance(address(this), alice), type(uint256).max);
        vault.decreaseAllowance(alice, x);
        assertEq(vault.allowance(address(this), alice), type(uint256).max - x);
        vault.decreaseAllowance(alice, x);
        assertEq(vault.allowance(address(this), alice), type(uint256).max - (x * 2));
        vault.decreaseAllowance(alice, x);
        assertEq(vault.allowance(address(this), alice), type(uint256).max - (x * 3));
        bool success = vault.decreaseAllowance(alice, x);
        assertEq(success, true);
        assertEq(vault.allowance(address(this), alice), type(uint256).max - (x * 4));
        vm.expectRevert();
        bool result = vault.decreaseAllowance(alice, type(uint256).max);
        assertEq(result, false);
    }

    function testShutdown() public {
        vm.prank(alice);
        vm.expectRevert(VaultErrors.OnlyRole.selector);
        vault.shutdownVault();

        assertEq(vault.shutdown(), false);

        vault.setRole(address(this), VaultEvents.Roles.EMERGENCY_MANAGER);
        vault.shutdownVault();
        assertEq(vault.depositLimit(), 0);
        assertEq(vault.depositLimitModule(), address(0));
        assertEq(vault.shutdown(), true);

        vm.expectRevert(VaultErrors.VaultShutdown.selector);
        vault.mint(100, address(this));
    }

    /**
     * Testing Assumptions:
     *         If the vault is shutdown the new debt level becomes 0
     *         the two debts can not be equal to one another
     *         if current debt is greater than the new debt it should withdraw the funds
     *             the amount is equal to the delta between the old and new debt
     *             However is the current idle + withdrawn assets is < min idle withdraw min idle
     *             make sure that we do not try to withdraw to much, and if it is withdraw what the max amount available is
     *             check for losses and if there are losses revert
     *             if not losses withdraw
     *             if withdrawn is greater than assets to withdraw convert ATW to withdrawn
     *             update the storage vars
     *         if new debt is greater (depositing into the strategy)
     *             make sure it is not higher than the max debt
     *             make sure max deposits is not 0
     *             amount to deposit is the difference between the new and current debt
     *             if it is greater than max swap to max
     *             check min idle needed and make sure deposit amount is not greater than min idle
     *             make sure deposits are greater than 0
     *             approve the asset for the strategy and deposit (after taking pre balance)
     *             take post balance
     *             reset approvals
     *             calculated actual deposited amount
     *             update storage for debt and idle
     *             update the strategy debt
     */
    function testUpdateDebt() public {
        vm.prank(alice);
        vm.expectRevert(VaultErrors.OnlyRole.selector);
        vault.updateDebt(address(0x02), 100);

        MockStrategy _strat = new MockStrategy(address(mock));
        vault.setRole(address(this), VaultEvents.Roles.ADD_STRATEGY_MANAGER);
        vault.addStrategy(address(_strat));
        vault.setRole(address(this), VaultEvents.Roles.DEBT_MANAGER);

        vm.expectRevert(VaultErrors.EquivilantDebt.selector);
        vault.updateDebt(address(_strat), 0);

        mock.approve(address(vault), type(uint256).max);
        vault.deposit(1_000_000 ether, address(this));

        /// Test Case 1: New debt is greater than current debt so we are depositing into the strategy.

        /// 1a: New debt is > than strategy max debt so revert else continue;
        vm.expectRevert(VaultErrors.OverMaxDebt.selector);
        vault.updateDebt(address(_strat), 1);

        vault.setRole(address(this), VaultEvents.Roles.MAX_DEBT_MANAGER);
        vault.updateMaxDebtForStrategy(address(_strat), 50_000 ether);
        _strat.setMaxDeposit(0);

        /// 1b: We are inputing a acceptable amount but the strategy will not let us deposit.
        vm.expectRevert(VaultErrors.ZeroDeposit.selector);
        vault.updateDebt(address(_strat), 10_000 ether);

        /// 1c: Case where the desired assets are > than the maximum deposit amount.
        /// It should switch to the maximum deposit amount;

        _strat.setMaxDeposit(5_000 ether);
        uint256 pre = mock.balanceOf(address(vault));
        vault.updateDebt(address(_strat), 10_000 ether);
        uint256 delta = pre - mock.balanceOf(address(vault));

        assertEq(delta, 5_000 ether);
        /// Post deposit allowance should be set back to 0
        assertEq(vault.allowance(address(vault), address(_strat)), 0);

        /// 1d: If the current required idle is > than the total idle revert.
        vault.setRole(address(this), VaultEvents.Roles.MINIMUM_IDLE_MANAGER);
        vault.setMinimumTotalIdle(type(uint256).max);
        vm.expectRevert(VaultErrors.InsufficentIdle.selector);
        vault.updateDebt(address(_strat), 15_000 ether);

        /// 1e: If the available idle is < the desired deposits just deposit the available.

        vault.setMinimumTotalIdle(992_500 ether);
        uint256 preSecond = mock.balanceOf(address(vault));
        vault.updateDebt(address(_strat), 15_000 ether);

        uint256 deltaSecond = preSecond - mock.balanceOf(address(vault));
        assertEq(vault.totalIdle(), 992_500 ether);
        assertEq(vault.totalDebt(), 7_500 ether);

        (,, uint256 current,) = vault.strategies(address(_strat));
        assertEq(current, 7_500 ether);

        /// Only the delta between the two idles should be able to be deposited
        assertEq(deltaSecond, 2_500 ether);

        /// Test Case 2: New debt is less than current debt so we are withdrawing from the strategy.

        /// 2a: Either the amount to withdraw + total idle is greater than minimum total idle
        /// or it is not. If it is not make the withdrawable assets eq. to the delta needed to
        /// get to minimum total idle. But if the delta is greater than total debt (deposits in the strategy)
        /// reset this to the deposited amount in the strategy.
        vault.setMinimumTotalIdle(995_000 ether);
        vault.updateDebt(address(_strat), 6_000 ether);
        assertEq(vault.totalDebt(), 5_000 ether);
        assertEq(vault.totalIdle(), 995_000 ether);

        /// 2b: Check what the maximum withdrawable amount from the strategy is. If it is 0 revert.
        /// if it is less than the currently calculated assets to withdraw make ATW = to max withdrawable.

        /// 2c: Calculate potential losses. If not equal to 0 a new report needs to be created prior to
        /// withdrawing from the strategy.

        /// 2d: withdraw from the stategy. Calculate withdrawn and account for potential losses.

        /// 2e: Check to make sure that withdraw is not greater than ATW if they are set ATW eq to withdrawn.

        /// 2f: Update store and set new debt eq to (current - assets to withdraw).

        /// Test Case 3: The vault is shut down and should automatically withdraw all funds if possible.

        // vault.setRole(address(this), VaultEvents.Roles.EMERGENCY_MANAGER);
        // vault.shutdownVault();
        // vault.updateDebt(address(_strat), 100_000 ether);
        // (,, uint256 shutdownCurrent, ) = vault.strategies(address(_strat));
        // assertEq(vault.totalDebt(), 0);
        // assertEq(vault.totalIdle(), 1_000_000 ether);
        // assertEq(shutdownCurrent, 0);

        /// If shutdown new debt should be 0, ie withdraw all funds from the strategy
        /// update strategy debt and return the new calculated debt
    }

    // function testRedeem() public {}

    // function testWithdraw() public {}
}

/// List of all functions to test and their associated visability / state

// ====================================================== \\
//                    EXTERNAL FUNCTIONS                  \\
// ====================================================== \\

// function approve(address spender, uint256 amount) external returns (bool); ✅

// function transfer(address receiver, uint256 amount) external returns (bool); ✅

// function transferFrom(address sender, address receiver, uint256 amount) external returns (bool); ✅

// function increaseAllowance(address spender, uint256 amount) external returns (bool); ✅

// function decreaseAllowance(address spender, uint256 amount) external returns (bool); ✅

// function addStrategy(address strategy) external; ✅

// function revokeStrategy(address strategy) external;

// function forceRevokeStrategy(address strategy) external;

// function updateMaxDebtForStrategy(address strategy, uint256 newMaxDebt) external;

// function updateDebt(address strategy, uint256 targetDebt) external returns (uint256);

// function shutdownVault() external; ✅

// function deposit(uint256 assets, address receiver) external returns (uint256);

// function mint(uint256 shares, address receiver) external returns (uint256);

// function processReport(address strategy) external returns (uint256, uint256);

// function buyDebt(address strategy, uint256 amount) external;

// function withdraw(uint256 assets, address receiver, address owner, uint256 maxLoss, address[10] calldata strats)
//     external
//     returns (uint256);

// function redeem(uint256 shares, address receiver, address owner, uint256 maxLoss, address[10] calldata strats)
//     external
//     returns (uint256);

// ====================================================== \\
//                     SETTER FUNCTIONS                   \\
// ====================================================== \\

// function setRole(address recipient, Roles role) external; ✅

// function removeRole(address account, Roles role) external; ✅

// function setOpenRole(Roles role) external; ✅

// function closeOpenRole(Roles role) external; ✅

// function transferRoleManger(address _roleManager) external; ✅

// function acceptRoleManager() external; ✅

// function setDepositLimit(uint256 _depositLimit) external; ✅

// function setAccountant(address newAccountant) external; ✅

// function setDefaultQueue(address[] calldata newDefaultQueue) external;

// function setUseDefaultQueue(bool _useDefaultQueue) external; ✅

// function setDepositLimitModule(address _depositLimitModule) external; ✅

// function setWithdrawLimitModule(address _withdrawLimitModule) external; ✅

// function setMinimumTotalIdle(uint256 _minimumTotalIdle) external; ✅

// function setProfitMaxUnlockTime(uint256 _profitMaxUnlockTime) external; ✅

// ====================================================== \\
//                  EXTERNAL VIEW FUNCTIONS               \\
// ====================================================== \\

// function balanceOf(address owner) external view returns (uint256);

// function previewWithdraw(uint256 assests) external view returns (uint256);

// function previewRedeem(uint256 shares) external view returns (uint256);

// function maxMint(address receiver) external view returns (uint256);

// function maxDeposit(address receiver) external view returns (uint256);

// function convertToAssets(uint256 shares) external view returns (uint256);

// function previewMint(uint256 shares) external view returns (uint256);

// function previewDeposits(uint256 assets) external view returns (uint256);

// function convertToShares(uint256 assets) external view returns (uint256);

// function totalAssets() external view returns (uint256);

// function maxRedeem(address owner, uint256 maxLoss, address[10] calldata strats) external view returns (uint256);

// function maxWithdraw(address owner, uint256 maxLoss, address[10] calldata strats) external view returns (uint256);

// function assessShareOfUnrealizedLosses(address strategy, uint256 assetsNeeded) external view returns (uint256);

// ====================================================== \\
//                    INTERNAL FUNCTIONS                  \\
// ====================================================== \\

// function _enforceRoles(address account, Roles role) private view;

// function _spendAllowance(address owner, address spender, uint256 amount) private;

// function _transfer(address sender, address receiver, uint256 amount) private;

// function _transferFrom(address sender, address receiver, uint256 amount) private returns (bool);

// function _approve(address owner, address spender, uint256 amount) private returns (bool);

// function _increaseAllowance(address owner, address spender, uint256 amount) private returns (bool);

// function _decreaseAllowance(address owner, address spender, uint256 amount) private returns (bool);

// function _burnShares(uint256 shares, address owner) private;

// function _unlockedShares() private view returns (uint256);

// function _totalSupply() private view returns (uint256);

// function _burnUnlockedShares() private;

// function _totalAssets() private view returns (uint256);

// function _convertToAssets(uint256 shares, Rounding rounding) private view returns (uint256);

// function _convertToShares(uint256 assets, Rounding rounding) private view returns (uint256);

// function _issueShares(uint256 shares, address recipient) private;

// function _issueSharesForAmount(uint256 amount, address recipient) internal returns (uint256);

// function _maxDeposit(address receiver) private view returns (uint256);

// function _maxWithdraw(address owner, uint256 maxLoss, address[MAX_QUEUE] calldata strats)
//     private
//     view
//     returns (uint256);

// function _deposit(address sender, address receipient, uint256 assets) private returns (uint256);

// function _mint(address sender, address receipient, uint256 shares) private returns (uint256);

// function _assessShareOfUnrealizedLosses(address strategy, uint256 assetsNeeded) private view returns (uint256);

// function _withdrawFromStrategy(address strategy, uint256 assetsToWithdraw) private;

// function _redeem(
//     address sender,
//     address receiver,
//     address owner,
//     uint256 assets,
//     uint256 sharesToBurn,
//     uint256 maxLoss,
//     address[MAX_QUEUE] calldata strats
// ) private returns (uint256);

// function _addStrategy(address newStrategy) private;

// function _revokeStrategy(address strategy, bool force) private;

// function _updateDebt(address strategy, uint256 targetDebt) private returns (uint256);

// function _processReport(address strategy) private returns (uint256, uint256);
