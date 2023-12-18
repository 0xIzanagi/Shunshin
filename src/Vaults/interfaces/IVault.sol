// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {VaultEvents} from "../VaultEvents.sol";
import {ERC20} from "oz/token/ERC20/ERC20.sol";

interface IVault {
    // ====================================================== \\
    //                    EXTERNAL FUNCTIONS                  \\
    // ====================================================== \\

    function addStrategy(address strategy) external;
    function revokeStrategy(address strategy) external;
    function forceRevokeStrategy(address strategy) external;
    function updateMaxDebtForStrategy(address strategy, uint256 newMaxDebt) external;
    function updateDebt(address strategy, uint256 targetDebt) external returns (uint256);
    function shutdownVault() external;
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function mint(uint256 shares, address receiver) external returns (uint256);
    function processReport(address strategy) external returns (uint256, uint256);
    function buyDebt(address strategy, uint256 amount) external;
    function withdraw(uint256 assets, address receiver, address owner, uint256 maxLoss, address[10] calldata strats)
        external
        returns (uint256);
    function redeem(uint256 shares, address receiver, address owner, uint256 maxLoss, address[10] calldata strats)
        external
        returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address receiver, uint256 amount) external returns (bool);
    function transferFrom(address sender, address receiver, uint256 amount) external returns (bool);
    function increaseAllowance(address spender, uint256 amount) external returns (bool);
    function decreaseAllowance(address spender, uint256 amount) external returns (bool);

    // ====================================================== \\
    //                     SETTER FUNCTIONS                   \\
    // ====================================================== \\

    function setRole(address recipient, VaultEvents.Roles role) external;
    function removeRole(address account, VaultEvents.Roles role) external;
    function setOpenRole(VaultEvents.Roles role) external;
    function closeOpenRole(VaultEvents.Roles role) external;
    function transferRoleManger(address _roleManager) external;
    function acceptRoleManager() external;
    function setDepositLimit(uint256 _depositLimit) external;
    function setAccountant(address newAccountant) external;
    function setDefaultQueue(address[] calldata newDefaultQueue) external;
    function setUseDefaultQueue(bool _useDefaultQueue) external;
    function setDepositLimitModule(address _depositLimitModule) external;
    function setWithdrawLimitModule(address _withdrawLimitModule) external;
    function setMinimumTotalIdle(uint256 _minimumTotalIdle) external;
    function setProfitMaxUnlockTime(uint256 _profitMaxUnlockTime) external;

    // ====================================================== \\
    //                  EXTERNAL VIEW FUNCTIONS               \\
    // ====================================================== \\

    function balanceOf(address owner) external view returns (uint256);
    function previewWithdraw(uint256 assets) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function maxMint(address receiver) external view returns (uint256);
    function maxDeposit(address receiver) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function previewMint(uint256 shares) external view returns (uint256);
    function previewDeposit(uint256 assets) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function totalDebt() external view returns (uint256);
    function totalIdle() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function decimals() external view returns (uint8);
    function asset() external view returns (ERC20);
    function totalSupply() external view returns (uint256);
    function maxRedeem(address owner, uint256 maxLoss, address[10] calldata strats) external view returns (uint256);
    function maxWithdraw(address owner, uint256 maxLoss, address[10] calldata strats) external view returns (uint256);
    function assessShareOfUnrealizedLosses(address strategy, uint256 assetsNeeded) external view returns (uint256);
    function profitMaxUnlockTime() external view returns (uint256);
    function fullProfitUnlockDate() external view returns (uint256);
    function profitUnlockingRate() external view returns (uint256);
    function lastProfitUpdate() external view returns (uint256);
}
