// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;
import {VaultEvents} from "../VaultEvents.sol";

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
    function withdraw(uint256 assets, address receiver, address owner, uint256 maxLoss, address[10] calldata strats) external returns(uint256);
    function redeem(uint256 shares, address receiver, address owner, uint256 maxLoss, address[10] calldata strats) external returns(uint256);
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
}