// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

abstract contract VaultEvents {
    enum Rounding {
        ROUND_DOWN,
        ROUND_UP
    }
    enum Roles {
        ADD_STRATEGY_MANAGER, // Can add strategies to the vault.
        REVOKE_STRATEGY_MANAGER, // Can remove strategies from the vault.
        FORCE_REVOKE_MANAGER, // Can force remove a strategy causing a loss.
        ACCOUNTANT_MANAGER, // Can set the accountant that assess fees.
        QUEUE_MANAGER, // Can set the default withdrawal queue.
        REPORTING_MANAGER, // Calls report for strategies.
        DEBT_MANAGER, // Adds and removes debt from strategies.
        MAX_DEBT_MANAGER, // Can set the max debt for a strategy.
        DEPOSIT_LIMIT_MANAGER, // Sets deposit limit and module for the vault.
        WITHDRAW_LIMIT_MANAGER, // Sets the withdraw limit module.
        MINIMUM_IDLE_MANAGER, // Sets the minimum total idle the vault should keep.
        PROFIT_UNLOCK_MANAGER, // Sets the profit_max_unlock_time.
        DEBT_PURCHASER, // Can purchase bad debt from the vault.
        EMERGENCY_MANAGER // Can shutdown vault in an emergency.
    }
    enum RoleStatusChange {
        OPENED,
        CLOSED
    }
    enum StrategyChangeType {
        ADDED,
        REVOKED
    }

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );
    event Transfer(address indexed sender, address indexed receiver, uint256 value);
    event Approval(address indexed sender, address indexed receiver, uint256 value);
    event StrategyChanged(address indexed strategy, StrategyChangeType indexed changeType);
    event StrategyReported(
        address indexed strategy,
        uint256 gain,
        uint256 loss,
        uint256 currentDebt,
        uint256 protocolFees,
        uint256 totalFees,
        uint256 totalRefunds
    );
    event DebtUpdated(address indexed strategy, uint256 currentDebt, uint256 newDebt);
    event RoleSet(address indexed account, Roles indexed role);
    event RoleStatusChanged(Roles indexed role, RoleStatusChange indexed status);
    event UpdateRoleManager(address indexed roleManager);
    event UpdateAccountant(address indexed accountant);
    event UpdateDepositLimit(uint256 limit);
    event UpdateDepositLimitModule(address indexed depositLimitModule);
    event UpdateWithdrawLimitModule(address indexed withdrawLimitModule);
    event UpdateDefaultQueue(address[] newDefaultQueue);
    event UpdateUseDefaultQueue(bool useDefaultQueue);
    event UpdatedMaxDebtForStrategy(address indexed sender, address indexed strategy, uint256 maxDebt);
    event UpdateMinimumTotalIdle(uint256 minimumTotalIdle);
    event UpdateProfitMaxUnlockTime(uint256 profitMaxUnlockTime);
    event DebtPurchased(address indexed strategy, uint256 amount);
}
