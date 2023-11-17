// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

abstract contract VaultErrors {
    error AssetsGtDebt();
    error MaxProfitUnlock();
    error InsufficentAllowance();
    error InsufficentBalance();
    error AmountTooHigh();
    error MaxDepositLimit();
    error ZeroAddress();
    error InvalidAsset();
    error StrategyActive();
    error StrategyInactive();
    error InactiveStrategy();
    error ZeroDeposit();
    error Shutdown();
    error MaxLoss();
    error WithdrawLimit();
    error InsufficentAssets();
    error EqualDebt();
    error MinIdle();
    error NoDeposits();
    error MaxDebt();
    error StrategeyLosses();
    error NoAvailableWithdraws();
    error OnlyRole();
    error OnlyRoleManager();
    error DepositLimitModuleActive();
    error DepositLimitActive();
    error OverProfitTL();
    error OnlyFutureRoleManager();
}
