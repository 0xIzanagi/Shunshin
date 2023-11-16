// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.23;

/// @title Vault Base
/// @author Koto Protocol
/// @notice Vaults Base for strategies based off of Yearn V3 Vaults
/// https://github.com/yearn/yearn-vaults-v3/blob/master/contracts/VaultV3.vy

import {ERC20} from "oz/token/ERC20/ERC20.sol";

contract VaultBase {
    uint8 private immutable decimals;
    ERC20 private immutable asset;
    address private immutable factory;
    uint256 private profitMaxUnlockTime;
    address private roleManager;
    string private name;
    string private symbol;

    constructor(
        address _asset,
        string memory _name,
        string memory _symbol,
        address _roleManager,
        uint256 _profitMaxUnlockTime
    ) {
        asset = ERC20(_asset);
        decimals = ERC20(_asset).decimals();
        factory = msg.sender;
        if (_profitMaxUnlockTime > 31_556_952) revert MaxProfitUnlock();
        profitMaxUnlockTime = _profitMaxUnlockTime;
        name = _name;
        symbol = _symbol;
        roleManager = _roleManager;
    }

    // ====================================================== \\
    //                     SETTER FUNCTIONS                   \\
    // ====================================================== \\

    function setAccountant(address newAccountant) external {}

    function setDefaultQueue(address[] calldata newDefaultQueue) external {}

    function setUseDefaultQueue(bool useDefaultQueue) external {}

    function setDepositLimit(uint256 depositLimit) external {}

    function setDepositLimitModule(address depositLimitModule) external {}

    function setWithdrawLimitModule(address withdrawLimitModule) external {}

    function setMinimumTotalIdle(uint256 minimumTotalIdle) external {}

    function setProfitMaxUnlockTime(uint256 newProfitMaxUnlockTime) external {}

    function setRole(address account) external {}

    function addRole(address account) external {}

    function removeRole(address account) external {}

    function setOpenRole() external {}

    function closeOpenRole() external {}

    function transferRoleManager(address newRoleManager) external {}

    function acceptRoleManager() external {}

    // ====================================================== \\
    //                    INTERNAL FUNCTIONS                  \\
    // ====================================================== \\

    function _spendAllowance(address owner, address spender, uint256 amount) private {}

    function _transfer(address from, address to, uint256 amount) private {}

    function _transferFrom(address from, address to, uint256 amount) private {}

    function _approve(address owner, address spender, uint256 amount) private {}

    function _increaseAllowance(address owner, address spender, uint256 amount) private {}

    function _decreaseAllowance(address owner, address spender, uint256 amount) private {}

    function _burnShares(address owner, uint256 shares) private {}

    function _unlockedShares() private view returns (uint256) {}

    function _totalSupply() private view returns (uint256) {}

    function _burnUnlockedShares() private {}

    function _totalAssets() private view returns (uint256) {}

    function _convertToAssets(uint256 shares, bool round) private returns (uint256) {}

    function _convertToShares(uint256 assets, bool round) private returns (uint256) {}

    // safe erc20 functions lines 510-525

    function _issueShares(address receiver, uint256 shares) private {}

    function _issueSharesForAmount(address receiver, uint256 amount) private {}

    function _maxDeposit(address receiver) private view returns (uint256) {}

    function _maxWithdraw(address owner, uint256 maxLoss, address[] calldata strategies)
        private
        view
        returns (uint256)
    {}

    function _deposit(address sender, address receiver, uint256 amount) private returns (uint256) {}

    function _mint(address sender, address receiver, uint256 amount) private returns (uint256) {}

    function _assessShareOfUnrealisedLosses(address strategy, uint256 assetsNeeded) private view returns (uint256) {}

    function _withdrawFromStrategy(address strategy, uint256 assetsToWithdraw) private {}

    function _redeem(
        address sender,
        address receiver,
        address owner,
        uint256 assets,
        uint256 sharesToBurn,
        uint256 maxLoss,
        address[] calldata strategies
    ) private returns (uint256) {}

    function _addStrategy(address newStrategy) private {}

    function _revokeStrategy(address strategy, bool force) private {}

    function _updateDebt(address strategy, uint256 targetDebt) private returns (uint256) {}

    function _processReport(address strategy) private returns (uint256, uint256) {}

    // ====================================================== \\
    //                  EXTERNAL VIEW FUNCTIONS               \\
    // ====================================================== \\

    function isShutdown() external view returns (bool) {}

    function unlockedShares() external view returns (uint256) {}

    function pricePerShare() external view returns (uint256) {}

    function getDefaultQueue() external view returns (address[] memory) {}

    // ====================================================== \\
    //                    REPORTING MANAGEMENT                \\
    // ====================================================== \\

    function processReport(address strategy) external returns (uint256, uint256) {}

    function buyDebt(address strategy, uint256 amount) external {}

    function addStrategy(address newStrategy) external {}

    function revokeStrategy(address strategy) external {}

    function forceRevokeStrategy(address strategy) external {}

    function updateMaxDebtForStrategy(address strategy, uint256 newMaxDebt) external {}

    function updateDebt(address strategy, uint256 targetDebt) external {}

    function shutdownVault() external {}

    function deposit(address receiver, uint256 assets) external returns (uint256) {}

    function mint(address receiver, uint256 shares) external returns (uint256) {}

    function withdraw(address receiver, address owner, uint256 assets, uint256 maxLoss, address[] calldata strategies)
        external
        returns (uint256)
    {}

    function redeem(address receiver, address owner, uint256 shares, uint256 maxLoss, address[] calldata strategies)
        external
        returns (uint256)
    {}

    function approve(address spender, uint256 amount) external returns (bool) {}

    function transfer(address receiver, uint256 amount) external returns (bool) {}

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {}

    function increaseAllowance(address spender, uint256 amount) external returns (bool) {}

    function decreaseAllowance(address spender, uint256 amount) external returns (bool) {}

    function balanceOf(address user) external view returns (uint256) {}

    function totalSupply() external view returns (uint256) {}

    // TODO: Lint
    function _asset() external view returns (address) {}

    // TODO: Lint
    function _decimals() external view returns (uint8) {}

    function totalAssets() external view returns (uint256) {}

    function totalIdle() external view returns (uint256) {}

    function totalDebt() external view returns (uint256) {}

    function convertToShares(uint256 assets) external view returns (uint256) {}

    function previewDeposit(uint256 assets) external view returns (uint256) {}

    function previewMint(uint256 shares) external view returns (uint256) {}

    function convertToAssets(uint256 shares) external view returns (uint256) {}

    function maxDeposit(address receiver) external view returns (uint256) {}

    function maxMint(address receiver) external view returns (uint256) {}

    function maxWithdraw(address owner, uint256 maxLoss, address[] calldata strategy) external view returns (uint256) {}

    function maxRedeem(address owner, uint256 maxLoss, address[] calldata strategies) external view returns (uint256) {}

    function previewWithdraw(uint256 shares) external view returns (uint256) {}

    function assessShareOfUnrealizedLosses(address strategy, uint256 assetsNeeded) external view returns (uint256) {}

    // TODO: Lint
    function _profitMaxUnlockTime() external view returns (uint256) {}

    function fullProfitUnlockDate() external view returns (uint256) {}

    function profitUnlockingRate() external view returns (uint256) {}

    function lastProfitUpdate() external view returns (uint256) {}

    error MaxProfitUnlock();
}
