// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

abstract contract VaultErrors {
    error ActiveStrategy();
    error DepositLimit();
    error EquivilantDebt();
    error InactiveStrategy();
    error InsufficentAllowance();
    error InsufficentBalance();
    error InsufficentIdle();
    error InvalidAsset();
    error InvalidStrategy();
    error InvalidTransfer();
    error OnlyRole();
    error OverMaxDebt();
    error StrategyUnrealizedLosses();
    error VaultShutdown();
    error ZeroAssets();
    error ZeroDeposit();
    error ZeroShares();
    error ZeroWithdraw();
}
