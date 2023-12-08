// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.23;

/// @title Vault
/// @author Koto Protocol
/// @notice Solidity implementation of Yearn V3 Vaults
/// https://github.com/yearn/yearn-vaults-v3/blob/master/contracts/VaultV3.vy

import {ERC20} from "oz/token/ERC20/ERC20.sol";
import {IDepositLimitModule} from "./interfaces/IDepositLimitModule.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {IWithdrawLimitModule} from "./interfaces/IWithdrawLimitModule.sol";
import {Math} from "oz/utils/math/Math.sol";
import {VaultErrors} from "./VaultErrors.sol";
import {VaultEvents} from "./VaultEvents.sol";

///Todo
/// 1. Visability of storage variables
/// 2. Create Vault Interface

contract Vault is VaultErrors, VaultEvents {
    struct StrategyParams {
        uint256 activation;
        uint256 lastReport;
        uint256 currentDebt;
        uint256 maxDebt;
    }

    // ====================================================== \\
    //                CONSTANTS AND IMMUTABLES                \\
    // ====================================================== \\

    uint256 public constant MAX_QUEUE = 10;
    uint256 public constant MAX_BPS = 10_000;
    uint256 public constant MAX_BPS_EXTENDED = 1_000_000_000_000;

    ERC20 public immutable asset;
    uint256 public immutable decimals;
    address public immutable factory;

    // ====================================================== \\
    //                     STORAGE VARIABLES                  \\
    // ====================================================== \\

    uint256 queueIndex;
    address[10] public defaultQueue;
    bool public useDefaultQueue;
    uint256 public totalSupply;
    uint256 totalDebt;
    uint256 totalIdle;
    uint256 minimumTotalIdle;
    uint256 depositLimit;
    address accountant;
    address depositLimitModule;
    address withdrawLimitModule;
    address roleManager;
    address futureRoleManager;
    string public name;
    string public symbol;
    bool shutdown;
    uint256 profitMaxUnlockTime;
    uint256 fullProfitUnlockDate;
    uint256 profitUnlockingRate;
    uint256 lastProfitUpdate;

    // ====================================================== \\
    //                          MAPPINGS                      \\
    // ====================================================== \\

    mapping(address => StrategyParams) public strategies;
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => mapping(Roles => bool)) public roles;
    mapping(Roles => bool) public openRoles;

    // ====================================================== \\
    //                        CONSTRUCTOR                     \\
    // ====================================================== \\

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _roleManager,
        uint256 _profitMaxUnlockTime
    ) {
        asset = _asset;
        decimals = _asset.decimals();
        factory = msg.sender;

        assert(profitMaxUnlockTime <= 31_556_952);
        profitMaxUnlockTime = _profitMaxUnlockTime;
        name = _name;
        symbol = _symbol;
        roleManager = _roleManager;
    }

    // ====================================================== \\
    //                    EXTERNAL FUNCTIONS                  \\
    // ====================================================== \\

    function addStrategy(address strategy) external {
        _enforceRoles(msg.sender, Roles.ADD_STRATEGY_MANAGER);
        _addStrategy(strategy);
    }

    function revokeStrategy(address strategy) external {
        _enforceRoles(msg.sender, Roles.REVOKE_STRATEGY_MANAGER);
        _revokeStrategy(strategy, false);
    }

    function forceRevokeStrategy(address strategy) external {
        _enforceRoles(msg.sender, Roles.FORCE_REVOKE_MANAGER);
        _revokeStrategy(strategy, true);
    }

    function updateMaxDebtForStrategy(address strategy, uint256 newMaxDebt) external {
        _enforceRoles(msg.sender, Roles.MAX_DEBT_MANAGER);
        if (strategies[strategy].activation == 0) revert InactiveStrategy();
        strategies[strategy].maxDebt = newMaxDebt;
        emit UpdatedMaxDebtForStrategy(msg.sender, strategy, newMaxDebt);
    }

    function updateDebt(address strategy, uint256 targetDebt) external returns (uint256) {
        _enforceRoles(msg.sender, Roles.DEBT_MANAGER);
        return _updateDebt(strategy, targetDebt);
    }

    function shutdownVault() external {
        _enforceRoles(msg.sender, Roles.EMERGENCY_MANAGER);
        if (shutdown) revert VaultShutdown();
        shutdown = true;
        depositLimit = 0;
        emit UpdateDepositLimit(0);
        if (depositLimitModule != address(0)) {
            depositLimitModule = address(0);
            emit UpdateDepositLimitModule(address(0));
        }
        roles[msg.sender][Roles.DEBT_MANAGER] = true;
        //emit Shutdown();
    }

    function deposit(uint256 assets, address receiver) external returns (uint256) {
        return _deposit(msg.sender, receiver, assets);
    }

    function mint(uint256 shares, address receiver) external returns (uint256) {
        return _mint(msg.sender, receiver, shares);
    }

    function withdraw() external {}

    function redeem() external {}

    function approve(address spender, uint256 amount) external returns (bool) {
        return _approve(msg.sender, spender, amount);
    }

    function transfer(address receiver, uint256 amount) external returns (bool) {
        if (receiver == address(this) || receiver == address(0)) revert InvalidTransfer();
        _transfer(msg.sender, receiver, amount);
        return true;
    }

    function transferFrom(address sender, address receiver, uint256 amount) external returns (bool) {
        if (receiver == address(this) || receiver == address(0)) revert InvalidTransfer();
        return _transferFrom(sender, receiver, amount);
    }

    function increaseAllowance(address spender, uint256 amount) external returns (bool) {
        return _increaseAllowance(msg.sender, spender, amount);
    }

    function decreaseAllowance(address spender, uint256 amount) external returns (bool) {
        return _decreaseAllowance(msg.sender, spender, amount);
    }

    // ====================================================== \\
    //                     SETTER FUNCTIONS                   \\
    // ====================================================== \\

    function setRole(address recipient, Roles role) external {
        if (msg.sender != roleManager) revert OnlyManager();
        roles[recipient][role] = true;
        emit RoleSet(recipient, role);
    }

    function removeRole(address account, Roles role) external {}

    function setOpenRole(Roles role) external {}

    function closeOpenRole(Roles role) external {}

    function transferRoleManger(address _roleManager) external {}

    function acceptRoleManager() external {}

    function setDepositLimit(uint256 _depositLimit) external {
        if (shutdown) revert VaultShutdown();
        if (depositLimitModule != address(0)) revert UsingDepositModule();
        _enforceRoles(msg.sender, Roles.DEPOSIT_LIMIT_MANAGER);
        depositLimit = _depositLimit;
        emit UpdateDepositLimit(_depositLimit);
    }

    function setAccountant(address newAccountant) external {
        _enforceRoles(msg.sender, Roles.ACCOUNTANT_MANAGER);
        accountant = newAccountant;
        emit UpdateAccountant(newAccountant);
    }

    function setDefaultQueue(address[] calldata newDefaultQueue) external {
        if (newDefaultQueue.length > MAX_QUEUE) revert MaxQueue();
        _enforceRoles(msg.sender, Roles.QUEUE_MANAGER);
        address[10] memory _newQueue;
        for (uint256 i = 0; i < newDefaultQueue.length; ++i) {
            if (strategies[newDefaultQueue[i]].activation == 0) revert InactiveStrategy();
            _newQueue[i] = newDefaultQueue[i];
        }

        defaultQueue = _newQueue;
        emit UpdateDefaultQueue(newDefaultQueue);
    }

    function setUseDefaultQueue(bool _useDefaultQueue) external {
        _enforceRoles(msg.sender, Roles.QUEUE_MANAGER);
        useDefaultQueue = _useDefaultQueue;
        emit UpdateUseDefaultQueue(_useDefaultQueue);
    }

    function setDepositLimitModule(address _depositLimitModule) external {
        _enforceRoles(msg.sender, Roles.DEPOSIT_LIMIT_MANAGER);
        if (depositLimit != type(uint256).max) revert UsingDepositLimit();
        if (shutdown) revert VaultShutdown();
        depositLimitModule = _depositLimitModule;
        emit UpdateDepositLimitModule(_depositLimitModule);
    }

    function setWithdrawLimitModule(address _withdrawLimitModule) external {}

    function setMinimumTotalIdle(uint256 _minimumTotalIdle) external {}

    function setProfitMaxUnlockTime(uint256 _profitMaxUnlockTime) external {}



    // ====================================================== \\
    //                  EXTERNAL VIEW FUNCTIONS               \\
    // ====================================================== \\

    function balanceOf(address owner) external view returns (uint256) {
        return balances[owner];
    }

    // ====================================================== \\
    //                    INTERNAL FUNCTIONS                  \\
    // ====================================================== \\

    function _enforceRoles(address account, Roles role) private view {
        if (!roles[account][role] && !openRoles[role]) revert OnlyRole();
    }

    function _spendAllowance(address owner, address spender, uint256 amount) private {
        uint256 currentAllowance = allowance[owner][spender];
        if (amount > currentAllowance) revert InsufficentAllowance();
        allowance[owner][spender] -= amount;
    }

    function _transfer(address sender, address receiver, uint256 amount) private {
        if (amount > balances[sender]) revert InsufficentBalance();
        unchecked {
            balances[sender] -= amount;
            balances[receiver] += amount;
        }
        emit Transfer(sender, receiver, amount);
    }

    function _transferFrom(address sender, address receiver, uint256 amount) private returns (bool) {
        _spendAllowance(sender, msg.sender, amount);
        _transfer(sender, receiver, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private returns (bool) {
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
        return true;
    }

    function _increaseAllowance(address owner, address spender, uint256 amount) private returns (bool) {
        allowance[owner][spender] += amount;
        emit Approval(owner, spender, amount);
        return true;
    }

    function _decreaseAllowance(address owner, address spender, uint256 amount) private returns (bool) {
        allowance[owner][spender] -= amount;
        return true;
    }
    ///Note: can use unchecked but need to add a additional safety check. Compare gas on that.

    function _burnShares(uint256 shares, address owner) private {
        balances[owner] -= shares;
        totalSupply -= shares;
        emit Transfer(owner, address(0), shares);
    }

    function _unlockedShares() private view returns (uint256) {
        uint256 _fullProfitUnlockDate = fullProfitUnlockDate;
        uint256 unlockedShares;
        if (_fullProfitUnlockDate > block.timestamp) {
            unlockedShares = profitUnlockingRate * (block.timestamp - lastProfitUpdate) / MAX_BPS_EXTENDED;
        } else if (_fullProfitUnlockDate != 0) {
            unlockedShares = balances[address(this)];
        }
        return unlockedShares;
    }

    function _totalSupply() private view returns (uint256) {
        return totalSupply - _unlockedShares();
    }

    function _burnUnlockedShares() private {
        uint256 unlockedShares = _unlockedShares();
        if (unlockedShares == 0) {
            return;
        }
        if (fullProfitUnlockDate > block.timestamp) {
            lastProfitUpdate = block.timestamp;
        }
        _burnShares(unlockedShares, address(this));
    }

    function _totalAssets() private view returns (uint256) {
        return totalIdle + totalDebt;
    }

    function _convertToAssets(uint256 shares, Rounding rounding) private view returns (uint256) {
        if (shares == type(uint256).max || shares == 0) {
            return shares;
        }
        uint256 ts = _totalSupply();
        if (totalSupply == 0) {
            return shares;
        }
        uint256 numerator = shares * _totalAssets();
        uint256 amount = numerator / ts;
        if (rounding == Rounding.ROUND_UP && numerator % ts != 0) {
            amount += 1;
        }
        return amount;
    }

    function _convertToShares(uint256 assets, Rounding rounding) private view returns (uint256) {
        if (assets == type(uint256).max || assets == 0) {
            return assets;
        }
        uint256 ts = _totalSupply();
        uint256 totalAssets = _totalAssets();

        if (totalAssets == 0) {
            if (ts == 0) {
                return assets;
            } else {
                return 0;
            }
        }
        uint256 numerator = assets * ts;
        uint256 shares = numerator / totalAssets;
        if (rounding == Rounding.ROUND_UP && numerator % totalAssets != 0) {
            shares += 1;
        }
        return shares;
    }

    function _issueShares(uint256 shares, address recipient) private {
        balances[recipient] += shares;
        totalSupply += shares;

        emit Transfer(address(0), recipient, shares);
    }

    function _issueSharesForAmount(uint256 amount, address recipient) internal returns (uint256) {
        uint256 ts = _totalSupply();
        uint256 totalAssets = _totalAssets();
        uint256 newShares;
        if (ts == 0) {
            newShares = amount;
        } else if (totalAssets > amount) {
            newShares = amount * ts / (totalAssets - amount);
        } else {
            assert(totalAssets > amount);
        }
        if (newShares == 0) {
            return 0;
        }
        _issueShares(newShares, recipient);
        return newShares;
    }

    function _maxDeposit(address receiver) private view returns (uint256) {
        if (receiver == address(0) || receiver == address(this)) {
            return 0;
        }
        address _depositLimitModule = depositLimitModule;
        if (_depositLimitModule != address(0)) {
            return IDepositLimitModule(_depositLimitModule).availableDepositLimit(receiver);
        }
        uint256 totalAssets = _totalAssets();
        uint256 _depositLimit = depositLimit;
        if (totalAssets >= _depositLimit) {
            return 0;
        }
        return (_depositLimit - totalAssets);
    }

    function _maxWithdraw(address owner, uint256 maxLoss, address[MAX_QUEUE] calldata strats)
        private
        view
        returns (uint256)
    {
        uint256 maxAssets = _convertToAssets(balances[address(this)], Rounding.ROUND_DOWN);
        address withdrawLimitMod = withdrawLimitModule;
        if (withdrawLimitModule != address(0)) {
            return Math.min(
                IWithdrawLimitModule(withdrawLimitMod).availableWithdrawLimit(owner, maxLoss, strats), maxAssets
            );
        }
        uint256 currentIdle = totalIdle;
        if (maxAssets > currentIdle) {
            uint256 have = currentIdle;
            uint256 loss;
            address[10] memory _strategies = defaultQueue;
            if (_strategies.length != 0 && !useDefaultQueue) {
                _strategies = strats;
            }
            for (uint256 i = 0; i < 10; ++i) {
                if (strategies[_strategies[i]].activation == 0) revert InactiveStrategy();
                uint256 toWithdraw = Math.min(maxAssets - have, strategies[_strategies[i]].currentDebt);
                uint256 unrealisedLosses = _assessShareOfUnrealizedLosses(_strategies[i], toWithdraw);
                uint256 strategyLimit =
                    IStrategy(_strategies[i]).convertToAssets(IStrategy(_strategies[i]).maxRedeem(address(this)));
                if (strategyLimit < toWithdraw - unrealisedLosses) {
                    unrealisedLosses = unrealisedLosses * strategyLimit / toWithdraw;
                    toWithdraw = strategyLimit + unrealisedLosses;
                }
                if (toWithdraw == 0) {
                    continue;
                }
                if (unrealisedLosses > 0 && maxLoss < MAX_BPS) {
                    if (loss + unrealisedLosses > (have + toWithdraw) * maxLoss / MAX_BPS) {
                        break;
                    }
                }
                have += toWithdraw;
                if (have >= maxAssets) {
                    break;
                }
                loss += unrealisedLosses;
            }
            maxAssets = have;
        }
        return maxAssets;
    }

    function _deposit(address sender, address receipient, uint256 assets) private returns (uint256) {
        if (shutdown == true) revert VaultShutdown();
        if (assets > _maxDeposit(receipient)) revert DepositLimit();
        asset.transferFrom(msg.sender, address(this), assets);
        totalIdle += assets;
        uint256 shares = _issueSharesForAmount(assets, receipient);
        if (shares == 0) revert ZeroShares();
        emit Deposit(sender, receipient, assets, shares);
        return shares;
    }

    function _mint(address sender, address receipient, uint256 shares) private returns (uint256) {
        if (shutdown == true) revert VaultShutdown();
        uint256 assets = _convertToAssets(shares, Rounding.ROUND_UP);
        if (assets == 0) revert ZeroAssets();
        if (assets > _maxDeposit(receipient)) revert DepositLimit();
        asset.transferFrom(msg.sender, address(this), assets);
        totalIdle += assets;
        _issueShares(shares, receipient);
        emit Deposit(sender, receipient, assets, shares);
        return assets;
    }

    function _assessShareOfUnrealizedLosses(address strategy, uint256 assetsNeeded) private view returns (uint256) {
        uint256 strategyCurrentDebt = strategies[strategy].currentDebt;
        uint256 vaultShares = IStrategy(strategy).balanceOf(address(this));
        uint256 strategyAssets = IStrategy(strategy).convertToAssets(vaultShares);
        if (strategyAssets >= strategyCurrentDebt || strategyCurrentDebt == 0) {
            return 0;
        }
        uint256 numerator = assetsNeeded * strategyAssets;
        uint256 lossesUserShare = assetsNeeded - numerator / strategyCurrentDebt;
        if (numerator % strategyCurrentDebt != 0) {
            lossesUserShare += 1;
        }
        return lossesUserShare;
    }

    function _withdrawFromStrategy(address strategy, uint256 assetsToWithdraw) private {
        uint256 sharesToRedeem = Math.min(
            IStrategy(strategy).previewWithdraw(assetsToWithdraw), IStrategy(strategy).balanceOf(address(this))
        );
        IStrategy(strategy).redeem(sharesToRedeem, address(this), address(this));
    }

    ///Note Skipped
    function _redeem(
        address sender,
        address receiver,
        address owner,
        uint256 assets,
        uint256 sharesToBurn,
        uint256 maxLoss,
        address[MAX_QUEUE] calldata strats
    ) private returns (uint256) {}

    function _addStrategy(address newStrategy) private {
        if (newStrategy == address(0) || newStrategy == address(this)) revert InvalidStrategy();
        if (IStrategy(newStrategy).asset() != address(asset)) revert InvalidAsset();
        if (strategies[newStrategy].activation != 0) revert ActiveStrategy();

        strategies[newStrategy] = StrategyParams(block.timestamp, block.timestamp, 0, 0);
        if (queueIndex < MAX_QUEUE) {
            defaultQueue[queueIndex] = newStrategy;
            queueIndex += 1;
        }
        emit StrategyChanged(newStrategy, StrategyChangeType.ADDED);
    }

    function _revokeStrategy(address strategy, bool force) private {
        if (strategies[strategy].activation == 0) revert InactiveStrategy();
        uint256 loss;
        ///Note if dept is greater than zero it should have to be forced to take on the loss, and should not be done by default.
        if (strategies[strategy].currentDebt != 0) {
            if (!force) revert ForceRequired();
            loss = strategies[strategy].currentDebt;
            totalDebt -= loss;
            emit StrategyReported(strategy, 0, loss, 0, 0, 0, 0);
        }
        strategies[strategy] = StrategyParams(0, 0, 0, 0);
        address[10] memory newQueue;
        for (uint256 i = 0; i < queueIndex;) {
            if (defaultQueue[i] != strategy) {
                newQueue[i] = defaultQueue[i];
            }
            unchecked {
                ++i;
            }
        }
        defaultQueue = newQueue;
        queueIndex -= 1;
        emit StrategyChanged(strategy, StrategyChangeType.REVOKED);
    }

    function _updateDebt(address strategy, uint256 targetDebt) private returns (uint256) {
        uint256 newDebt = targetDebt;
        uint256 currentDebt = strategies[strategy].currentDebt;
        if (shutdown) {
            newDebt = 0;
        }
        if (newDebt == currentDebt) revert EquivilantDebt();
        if (currentDebt > newDebt) {
            uint256 assetsToWithdraw = currentDebt - newDebt;
            uint256 _minimumTotalIdle = minimumTotalIdle;
            uint256 _totalIdle = totalIdle;
            if (_totalIdle + assetsToWithdraw < _minimumTotalIdle) {
                assetsToWithdraw = _minimumTotalIdle - _totalIdle;
                if (assetsToWithdraw > currentDebt) {
                    assetsToWithdraw = currentDebt;
                }
            }
            uint256 withdrawable = IStrategy(strategy).convertToAssets(IStrategy(strategy).maxRedeem(address(this)));
            if (withdrawable == 0) revert ZeroWithdraw();
            if (withdrawable < assetsToWithdraw) {
                assetsToWithdraw = withdrawable;
            }
            uint256 unrealisedLossesShare = _assessShareOfUnrealizedLosses(strategy, assetsToWithdraw);
            if (unrealisedLossesShare != 0) revert StrategyUnrealizedLosses();
            uint256 preBalance = asset.balanceOf(address(this));
            _withdrawFromStrategy(strategy, assetsToWithdraw);
            uint256 postBalance = asset.balanceOf(address(this));
            uint256 withdrawn = Math.min(postBalance - preBalance, currentDebt);
            if (withdrawn > assetsToWithdraw) {
                assetsToWithdraw = withdrawn;
            }
            totalIdle += withdrawn;
            totalDebt -= assetsToWithdraw;
            newDebt = currentDebt - assetsToWithdraw;
        } else {
            if (newDebt > strategies[strategy].maxDebt) revert OverMaxDebt();
            uint256 maxDeposit = IStrategy(strategy).maxDeposit(address(this));
            if (maxDeposit == 0) revert ZeroDeposit();
            uint256 assetsToDeposit = newDebt - currentDebt;
            if (assetsToDeposit > maxDeposit) {
                assetsToDeposit = maxDeposit;
            }
            uint256 _minimumTotalIdle = minimumTotalIdle;
            uint256 _totalIdle = totalIdle;
            if (_totalIdle <= _minimumTotalIdle) revert InsufficentIdle();
            uint256 availableIdle = _totalIdle - _minimumTotalIdle;
            if (assetsToDeposit > availableIdle) {
                assetsToDeposit = availableIdle;
            }
            if (assetsToDeposit > 0) {
                asset.approve(strategy, assetsToDeposit);
                uint256 preBalance = asset.balanceOf(address(this));
                IStrategy(strategy).deposit(assetsToDeposit, address(this));
                uint256 postBalance = asset.balanceOf(address(this));
                asset.approve(strategy, 0);
                assetsToDeposit = preBalance - postBalance;
                totalIdle -= assetsToDeposit;
                totalDebt += assetsToDeposit;
            }
            newDebt = currentDebt + assetsToDeposit;
        }
        strategies[strategy].currentDebt = newDebt;
        emit DebtUpdated(strategy, currentDebt, newDebt);
        return newDebt;
    }

    ///Note Skipped
    function _processReport(address strategy) private returns (uint256, uint256) {}
}
