// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

abstract contract VaultErrors {
    error ActiveStrategy();
    error DepositLimit();
    error EquivilantDebt();
    error ForceRequired();
    error InactiveStrategy();
    error InsufficentAllowance();
    error InsufficentAssets();
    error InsufficentBalance();
    error InsufficentIdle();
    error InsufficentVaultAssets();
    error InvalidAsset();
    error InvalidStrategy();
    error InvalidTransfer();
    error MaxLoss();
    error MaxQueue();
    error OnlyManager();
    error OnlyRole();
    error OverMaxDebt();
    error ProfitUnlockTime();
    error StrategyUnrealizedLosses();
    error VaultShutdown();
    error UsingDepositModule();
    error UsingDepositLimit();
    error WithdrawLimit();
    error ZeroAddress();
    error ZeroAssets();
    error ZeroDebt();
    error ZeroDeposit();
    error ZeroShares();
    error ZeroWithdraw();
}
