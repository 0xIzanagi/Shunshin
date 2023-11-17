// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.23;

/// @title Vault Base
/// @author Koto Protocol
/// @notice Solidity implementation of Yearn V3 Vaults
/// https://github.com/yearn/yearn-vaults-v3/blob/master/contracts/VaultV3.vy

///Todo: Major Cleanup
/// Move Errors and events to their own contract.

import {ERC20} from "oz/token/ERC20/ERC20.sol";
import {IAccountant} from "./interfaces/IAccountant.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {IWithdrawLimitModule} from "./interfaces/IWithdrawLimitModule.sol";
import {IDepositLimitModule} from "./interfaces/IDepositLimitModule.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {VaultErrors} from "./VaultErrors.sol";
import {VaultEvents} from "./VaultEvents.sol";

contract VaultBase is VaultErrors, VaultEvents {
    // ====================================================== \\
    //                           STRUCTS                      \\
    // ====================================================== \\

    struct StrategyParams {
        uint256 activation;
        uint256 lastReport;
        uint256 currentDebt;
        uint256 maxDebt;
    }

    // ====================================================== \\
    //                          ROLES                         \\
    // ====================================================== \\

    enum Roles {
        ADD_STRATEGY_MANAGER, // Can add strategies to the vault.
        REVOKE_STRATEGY_MANAGER, // Can remove strategies from the vault.
        FORCE_REVOKE_MANAGER, //Can force remove a strategy causing a loss.
        ACCOUNTANT_MANAGER, //Can set the accountant that assess fees.
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

    // ====================================================== \\
    //                CONSTANTS AND IMMUTABLES                \\
    // ====================================================== \\

    uint256 private constant MAX_BPS_EXTENDED = 1_000_000_000_000;
    uint256 private constant MAX_BPS = 10_000;
    uint256 private constant MAX_QUEUE = 10;
    uint8 private immutable _decimals;
    ERC20 private immutable _asset;
    address private immutable factory;

    // ====================================================== \\
    //                     STORAGE VARIABLES                  \\
    // ====================================================== \\

    string private _name;
    string private _symbol;
    address private _roleManager;
    address private _futureRoleManager;
    address private _withdrawLimitModule;
    address private _depositLimitModule;
    address private _accountant;
    bool private shutdown;
    bool private _useDefaultQueue;
    uint8 private _queueIndex;
    address[MAX_QUEUE] private _defaultQueue;
    uint256 private _profitUnlockingRate;
    uint256 private _profitMaxUnlockTime;
    uint256 private _totalSupply;
    uint256 private _totalIdle;
    uint256 private _totalDebt;
    uint256 private _depositLimit;
    uint256 private _fullProfitUnlockDate;
    uint256 private _lastProfitUpdate;
    uint256 private _minimumTotalIdle;

    // ====================================================== \\
    //                          MAPPINGS                      \\
    // ====================================================== \\

    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => StrategyParams) public strategies;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(Roles => bool)) private _roles;
    mapping(Roles => bool) private _openRoles;

    // ====================================================== \\
    //                        MODIFIERS                       \\
    // ====================================================== \\

    // Comeback to update this
    function _enforeRole(address sender, Roles role) private view {
        if (!_roles[sender][role] && !_openRoles[role]) revert OnlyRole();
    }

    // ====================================================== \\
    //                        CONSTRUCTOR                     \\
    // ====================================================== \\

    constructor(
        address _asset_,
        string memory _name_,
        string memory _symbol_,
        address _roleManager_,
        uint256 _profitMaxUnlockTime_
    ) {
        _asset = ERC20(_asset_);
        _decimals = ERC20(_asset).decimals();
        factory = msg.sender;
        if (_profitMaxUnlockTime_ > 31_556_952) revert MaxProfitUnlock();
        _profitMaxUnlockTime = _profitMaxUnlockTime_;
        _name = _name_;
        _symbol = _symbol_;
        _roleManager = _roleManager_;
    }

    // ====================================================== \\
    //                     SETTER FUNCTIONS                   \\
    // ====================================================== \\

    function setAccountant(address newAccountant) external {
        _enforeRole(msg.sender, Roles.ACCOUNTANT_MANAGER);
        _accountant = newAccountant;
    }

    function setDefaultQueue(address[10] calldata newDefaultQueue) external {
        _enforeRole(msg.sender, Roles.QUEUE_MANAGER);
        for (uint256 i = 0; i < newDefaultQueue.length;) {
            if (strategies[newDefaultQueue[i]].activation == 0) revert InactiveStrategy();
            unchecked {
                ++i;
            }
        }
        _defaultQueue = newDefaultQueue;
    }

    function setUseDefaultQueue(bool _useDefaultQueue_) external {
        _enforeRole(msg.sender, Roles.QUEUE_MANAGER);
        _useDefaultQueue = _useDefaultQueue_;
    }

    function setDepositLimit(uint256 _depositLimit_) external {
        if (shutdown) revert Shutdown();
        _enforeRole(msg.sender, Roles.DEPOSIT_LIMIT_MANAGER);
        if (_depositLimitModule != address(0)) revert DepositLimitModuleActive();
        _depositLimit = _depositLimit_;
    }

    function setDepositLimitModule(address _depositLimitModule_) external {
        if (shutdown) revert Shutdown();
        _enforeRole(msg.sender, Roles.DEPOSIT_LIMIT_MANAGER);
        if (_depositLimit != type(uint256).max) revert DepositLimitActive();
        _depositLimitModule = _depositLimitModule_;
    }

    function setWithdrawLimitModule(address _withdrawLimitModule_) external {
        _enforeRole(msg.sender, Roles.WITHDRAW_LIMIT_MANAGER);
        _withdrawLimitModule = _withdrawLimitModule_;
    }

    function setMinimumTotalIdle(uint256 _minimumTotalIdle_) external {
        _enforeRole(msg.sender, Roles.MINIMUM_IDLE_MANAGER);
        _minimumTotalIdle = _minimumTotalIdle_;
    }

    function setProfitMaxUnlockTime(uint256 newProfitMaxUnlockTime) external {
        _enforeRole(msg.sender, Roles.PROFIT_UNLOCK_MANAGER);
        if (newProfitMaxUnlockTime > 31_556_952) revert OverProfitTL();
        if (newProfitMaxUnlockTime == 0) {
            _burnShares(address(this), _balances[address(this)]);
            _profitUnlockingRate = 0;
            _fullProfitUnlockDate = 0;
        }
        _profitMaxUnlockTime = newProfitMaxUnlockTime;
    }

    function setRole(address account, Roles role, bool active) external {
        if (msg.sender != _roleManager) revert OnlyRoleManager();
        _roles[account][role] = active;
    }

    function addRole(address account, Roles role) external {
        if (msg.sender != _roleManager) revert OnlyRoleManager();
        _roles[account][role] = true;
    }

    function removeRole(address account, Roles role) external {
        if (msg.sender != _roleManager) revert OnlyRoleManager();
        _roles[account][role] = false;
    }

    function setOpenRole(Roles role) external {
        if (msg.sender != _roleManager) revert OnlyRoleManager();
        _openRoles[role] = true;
    }

    function closeOpenRole(Roles role) external {
        if (msg.sender != _roleManager) revert OnlyRoleManager();
        _openRoles[role] = false;
    }

    function transferRoleManager(address newRoleManager) external {
        if (msg.sender != _roleManager) revert OnlyRoleManager();
        _futureRoleManager = newRoleManager;
    }

    function acceptRoleManager() external {
        if (msg.sender != _futureRoleManager) revert OnlyFutureRoleManager();
        _roleManager = msg.sender;
        _futureRoleManager = address(0);
    }

    // ====================================================== \\
    //                    INTERNAL FUNCTIONS                  \\
    // ====================================================== \\

    function _spendAllowance(address owner, address spender, uint256 amount) private {
        uint256 current = allowance[owner][spender];
        if (current < type(uint256).max) {
            if (amount > current) revert InsufficentAllowance();
            allowance[owner][spender] = current - amount;
        }
    }

    function _transfer(address from, address to, uint256 amount) private {
        if (amount > _balances[from]) revert InsufficentBalance();
        unchecked {
            _balances[from] -= amount;
            _balances[to] += amount;
        }
    }

    function _transferFrom(address from, address to, uint256 amount) private returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private returns (bool) {
        allowance[owner][spender] = amount;
        return true;
    }

    function _increaseAllowance(address owner, address spender, uint256 amount) private returns (bool) {
        allowance[owner][spender] += amount;
        return true;
    }

    function _decreaseAllowance(address owner, address spender, uint256 amount) private returns (bool) {
        allowance[owner][spender] -= amount;
        return true;
    }

    function _burnShares(address owner, uint256 shares) private {
        if (_balances[owner] < shares) revert InsufficentBalance();
        unchecked {
            _balances[owner] -= shares;
            _totalSupply -= shares;
        }
    }

    function _unlockedShares() private view returns (uint256) {
        uint256 _fullProfitDate_ = _fullProfitUnlockDate;
        uint256 unlocked;
        if (_fullProfitDate_ > block.timestamp) {
            unlocked = _profitUnlockingRate * (block.timestamp - _lastProfitUpdate) / MAX_BPS_EXTENDED;
        } else if (_fullProfitDate_ != 0) {
            unlocked = _balances[address(this)];
        }
        return unlocked;
    }

    function totalSupply() private view returns (uint256) {
        return _totalSupply - _unlockedShares();
    }

    function _burnUnlockedShares() private {
        uint256 unlocked = _unlockedShares();
        if (unlocked > 0) {
            if (_fullProfitUnlockDate > block.timestamp) {
                _lastProfitUpdate = block.timestamp;
            }
            _burnShares(address(this), unlocked);
        }
    }

    function _totalAssets() private view returns (uint256) {
        return _totalIdle + _totalDebt;
    }

    function _convertToAssets(uint256 shares, bool round) private view returns (uint256) {
        if (shares == type(uint256).max || shares == 0) {
            return shares;
        }
        uint256 ts = totalSupply();
        if (ts == 0) {
            return shares;
        }
        uint256 num = shares * _totalAssets();
        uint256 amount = num / ts;
        if (round == true && num / ts != 0) {
            amount += 1;
        }
        return amount;
    }

    function _convertToShares(uint256 assets, bool round) private view returns (uint256) {
        if (assets == type(uint256).max || assets == 0) {
            return assets;
        }
        uint256 ts = totalSupply();
        uint256 ta = _totalAssets();

        if (ta == 0) {
            if (ts == 0) {
                return assets;
            } else {
                return 0;
            }
        }

        uint256 num = assets * ts;
        uint256 shares = num / ta;

        if (round == true && num / ta != 0) {
            shares += 1;
        }
        return shares;
    }

    function _issueShares(address receiver, uint256 shares) private {
        unchecked {
            _balances[receiver] += shares;
            _totalSupply += shares;
        }
    }

    function _issueSharesForAmount(address receiver, uint256 amount) private returns (uint256) {
        uint256 ts = totalSupply();
        uint256 ta = _totalAssets();
        uint256 newShares;

        if (ts == 0) {
            newShares = amount;
        } else if (ta > amount) {
            newShares = (amount * ts) / (ta - amount);
        } else {
            if (ta > amount) revert AmountTooHigh();
        }

        if (newShares == 0) {
            return 0;
        }

        _issueShares(receiver, newShares);
        return newShares;
    }

    function _maxDeposit(address receiver) private view returns (uint256) {
        address dlm = _depositLimitModule;
        if (dlm != address(0)) {
            return IDepositLimitModule(dlm).availableDepositLimit(receiver);
        }

        uint256 ta = _totalAssets();
        uint256 dl = _depositLimit;
        if (dl < ta) {
            return 0;
        }
        return (dl - ta);
    }

    function _maxWithdraw(address owner, uint256 maxLoss, address[10] calldata _strats)
        private
        view
        returns (uint256)
    {
        uint256 maxAssets = _convertToAssets(_balances[owner], false);
        address wlm = _withdrawLimitModule;
        if (wlm != address(0)) {
            uint256 limit = IWithdrawLimitModule(wlm).availableWithdrawLimit(owner, maxLoss, _strats);
            uint256 amount = maxAssets > limit ? limit : maxAssets;
            return amount;
        }
        uint256 currentIdle = _totalIdle;
        if (maxAssets > currentIdle) {
            uint256 have = currentIdle;
            uint256 loss;

            address[10] memory _strategies = _defaultQueue;
            if (_strats.length != 0 && !_useDefaultQueue) {
                _strategies = _strats;
            }
            for (uint256 i = 0; i < _strategies.length;) {
                if (strategies[_strategies[i]].activation == 0) revert InactiveStrategy();
                uint256 toWithdraw = maxAssets - have > strategies[_strategies[i]].currentDebt
                    ? strategies[_strategies[i]].currentDebt
                    : maxAssets - have;
                uint256 unrealisedLoss = _assessShareOfUnrealisedLosses(_strategies[i], toWithdraw);
                uint256 strategyLimit =
                    IStrategy(_strategies[i]).convertToAssets(IStrategy(_strategies[i]).maxRedeem(address(this)));

                if (strategyLimit < toWithdraw - unrealisedLoss) {
                    unrealisedLoss = unrealisedLoss * strategyLimit / toWithdraw;
                    toWithdraw = strategyLimit + unrealisedLoss;
                }
                if (toWithdraw == 0) {
                    continue;
                }
                if (unrealisedLoss > 0 && maxLoss < MAX_BPS) {
                    if (loss + unrealisedLoss > (have + toWithdraw) * maxLoss * MAX_BPS) {
                        break;
                    }
                }
                have += toWithdraw;
                if (maxAssets < have) {
                    break;
                }
                loss += unrealisedLoss;
            }
            maxAssets = have;
        }
        return maxAssets;
    }

    function _deposit(address sender, address receiver, uint256 amount) private returns (uint256) {
        if (shutdown == true) revert Shutdown();
        if (amount > _maxDeposit(receiver)) revert MaxDepositLimit();
        _asset.transferFrom(sender, address(this), amount);
        _totalIdle += amount;
        uint256 shares = _issueSharesForAmount(receiver, amount);
        return shares;
    }

    function _mint(address sender, address receiver, uint256 amount) private returns (uint256) {
        if (shutdown == true) revert Shutdown();
        uint256 assets = _convertToAssets(amount, true);
        if (assets == 0) revert ZeroDeposit();
        if (assets > _maxDeposit(receiver)) revert MaxDepositLimit();
        _asset.transferFrom(sender, address(this), amount);
        _totalIdle += assets;
        _issueShares(receiver, amount);
        return assets;
    }

    function _assessShareOfUnrealisedLosses(address strategy, uint256 assetsNeeded) private view returns (uint256) {
        uint256 strategyCurrentDebt = strategies[strategy].currentDebt;
        uint256 vaultShares = IStrategy(strategy).balanceOf(address(this));
        uint256 strategyAssets = IStrategy(strategy).convertToAssets(vaultShares);

        if (strategyAssets >= strategyCurrentDebt || strategyCurrentDebt == 0) {
            return 0;
        }

        uint256 num = assetsNeeded * strategyAssets;
        uint256 lossesUserShare = assetsNeeded - num / strategyCurrentDebt;
        if (num / strategyCurrentDebt != 0) {
            lossesUserShare += 1;
        }
        return lossesUserShare;
    }

    function _withdrawFromStrategy(address strategy, uint256 assetsToWithdraw) private {
        uint256 sharesToRedeem = IStrategy(strategy).previewWithdraw(assetsToWithdraw)
            > IStrategy(strategy).balanceOf(address(this))
            ? IStrategy(strategy).balanceOf(address(this))
            : IStrategy(strategy).previewWithdraw(assetsToWithdraw);
        IStrategy(strategy).redeem(sharesToRedeem, address(this), address(this));
    }

    function _redeem(
        address sender,
        address receiver,
        address owner,
        uint256 assets,
        uint256 sharesToBurn,
        uint256 maxLoss,
        address[10] calldata _strats
    ) private returns (uint256) {
        uint256 shares = sharesToBurn;
        //uint256 sharesBalance = _balances[address(this)];
        if (receiver == address(0)) revert ZeroAddress();
        if (maxLoss > MAX_BPS) revert MaxLoss();
        if (_withdrawLimitModule != address(0)) {
            if (assets > _maxWithdraw(owner, maxLoss, _strats)) revert WithdrawLimit();
        }

        if (sender != owner) {
            _spendAllowance(owner, sender, sharesToBurn);
        }

        uint256 requestedAssets = assets;
        uint256 currentTotalIdle = _totalIdle;

        if (requestedAssets > currentTotalIdle) {
            address[10] memory _strategies = _defaultQueue;

            if (_strats.length != 0 && !_useDefaultQueue) {
                _strategies = _strats;
            }
            uint256 currentTotalDebt = _totalDebt;
            uint256 assetsNeeded = requestedAssets - currentTotalIdle;
            uint256 assetsToWithdraw;
            uint256 previousBalance = _asset.balanceOf(address(this));
            for (uint256 i = 0; i < _strategies.length;) {
                if (strategies[_strategies[i]].activation == 0) revert InactiveStrategy();
                uint256 currentDebt = strategies[_strategies[i]].currentDebt;
                assetsToWithdraw = assetsNeeded > currentDebt ? currentDebt : assetsNeeded;
                uint256 maxWithdraw_ =
                    IStrategy(_strategies[i]).convertToAssets(IStrategy(_strategies[i]).maxRedeem(address(this)));
                uint256 unrealisedLoss = _assessShareOfUnrealisedLosses(_strategies[i], assetsToWithdraw);
                if (unrealisedLoss > 0) {
                    if (maxWithdraw_ < assetsToWithdraw - unrealisedLoss) {
                        uint256 wanted = assetsToWithdraw - unrealisedLoss;
                        unrealisedLoss = (unrealisedLoss * maxWithdraw_) / wanted;
                    }
                }
                assetsToWithdraw -= unrealisedLoss;
                requestedAssets -= unrealisedLoss;
                assetsNeeded -= unrealisedLoss;
                currentTotalDebt -= unrealisedLoss;

                if (maxWithdraw_ == 0 && unrealisedLoss > 0) {
                    uint256 newDebt = currentDebt - unrealisedLoss;
                    strategies[_strategies[i]].currentDebt = newDebt;
                }
                if (assetsToWithdraw == 0) {
                    continue;
                }
                _withdrawFromStrategy(_strategies[i], assetsToWithdraw);
                uint256 postBalance = _asset.balanceOf(address(this));
                uint256 withdrawn = postBalance - previousBalance;
                uint256 loss;
                if (withdrawn > assetsToWithdraw) {
                    if (withdrawn > currentDebt) {
                        assetsToWithdraw = currentDebt;
                    } else {
                        assetsToWithdraw += withdrawn - assetsToWithdraw;
                    }
                } else if (withdrawn < assetsToWithdraw) {
                    loss = assetsToWithdraw - withdrawn;
                }
                currentTotalIdle += assetsToWithdraw - loss;
                requestedAssets -= loss;
                currentTotalDebt -= assetsToWithdraw;
                uint256 _newDebt = currentDebt - (assetsToWithdraw + unrealisedLoss);
                strategies[_strategies[i]].currentDebt = _newDebt;
                if (requestedAssets < currentTotalIdle) {
                    break;
                }
                previousBalance = postBalance;
                assetsNeeded -= assetsToWithdraw;
            }
            if (currentTotalIdle < requestedAssets) revert InsufficentAssets();
            _totalDebt = currentTotalDebt;
        }
        if (assets > requestedAssets && maxLoss < MAX_BPS) {
            if (assets - requestedAssets > assets * maxLoss / MAX_BPS) revert MaxLoss();
        }
        _burnShares(owner, shares);
        _totalIdle = currentTotalIdle - requestedAssets;
        _asset.transfer(receiver, requestedAssets);
        return requestedAssets;
    }

    function _addStrategy(address newStrategy) private {
        if (newStrategy == address(0)) revert ZeroAddress();
        if (IStrategy(newStrategy).asset() != address(_asset)) revert InvalidAsset();
        if (strategies[newStrategy].activation != 0) revert StrategyActive();
        strategies[newStrategy] = StrategyParams(block.timestamp, block.timestamp, 0, 0);
        if (_defaultQueue.length < MAX_QUEUE) {
            _defaultQueue[_queueIndex] = newStrategy;
            _queueIndex += 1;
        }
    }

    function _revokeStrategy(address strategy, bool force) private {
        if (strategies[strategy].activation == 0) revert StrategyInactive();
        uint256 loss;
        if (strategies[strategy].currentDebt != 0) {
            assert(force);
            loss = strategies[strategy].currentDebt;
            _totalDebt -= loss;
        }
        strategies[strategy] = StrategyParams(0, 0, 0, 0);
    }

    function _updateDebt(address strategy, uint256 targetDebt) private returns (uint256) {
        uint256 newDebt = targetDebt;
        uint256 currentDebt = strategies[strategy].currentDebt;
        if (shutdown) {
            newDebt = 0;
        }
        if (newDebt == currentDebt) revert EqualDebt();
        if (currentDebt > newDebt) {
            uint256 assetsToWithdraw = currentDebt - newDebt;
            uint256 _minTotalIdle = _minimumTotalIdle;

            if (_totalIdle + assetsToWithdraw < _minTotalIdle) {
                if (assetsToWithdraw > currentDebt) {
                    assetsToWithdraw = currentDebt;
                }
                uint256 withdrawable = IStrategy(strategy).convertToAssets(IStrategy(strategy).maxRedeem(address(this)));
                if (withdrawable == 0) revert NoAvailableWithdraws();
                if (withdrawable < assetsToWithdraw) {
                    assetsToWithdraw = withdrawable;
                }
                uint256 unrealisedLoss = _assessShareOfUnrealisedLosses(strategy, assetsToWithdraw);
                if (unrealisedLoss != 0) revert StrategeyLosses();
                uint256 preBalance = _asset.balanceOf(address(this));
                _withdrawFromStrategy(strategy, assetsToWithdraw);
                uint256 postBalance = _asset.balanceOf(address(this));
                uint256 withdrawn = currentDebt > (postBalance - preBalance) ? (postBalance - preBalance) : currentDebt;
                if (withdrawn > assetsToWithdraw) {
                    assetsToWithdraw = withdrawn;
                }
                _totalIdle += withdrawn;
                _totalDebt -= assetsToWithdraw;
                newDebt = currentDebt - assetsToWithdraw;
            } else {
                if (newDebt > strategies[strategy].maxDebt) revert MaxDebt();
                uint256 maxDeposit_ = IStrategy(strategy).maxDeposit(address(this));
                if (maxDeposit_ == 0) revert NoDeposits();
                uint256 assetsToDeposit = newDebt - currentDebt;
                if (assetsToDeposit > maxDeposit_) {
                    assetsToDeposit = maxDeposit_;
                }
                uint256 _totalIdle_ = _totalIdle;
                if (_totalIdle_ < _minTotalIdle) revert MinIdle();
                uint256 availableIdle = _totalIdle_ - _minTotalIdle;
                if (assetsToDeposit > availableIdle) {
                    assetsToDeposit = availableIdle;
                }
                if (assetsToDeposit > 0) {
                    _asset.approve(strategy, assetsToDeposit);
                    uint256 preBalance = _asset.balanceOf(address(this));
                    IStrategy(strategy).deposit(assetsToDeposit, address(this));
                    uint256 postBalance = _asset.balanceOf(address(this));
                    _asset.approve(strategy, 0);
                    assetsToDeposit = preBalance - postBalance;
                    _totalIdle -= assetsToDeposit;
                    _totalDebt += assetsToDeposit;
                }
                newDebt = currentDebt + assetsToDeposit;
            }
        }
        strategies[strategy].currentDebt = newDebt;
        return newDebt;
    }

    function _processReport(address strategy) private returns (uint256, uint256) {
        if (strategies[strategy].activation == 0) revert InactiveStrategy();
        _burnUnlockedShares();
        uint256 strategyShares = IStrategy(strategy).balanceOf(address(this));
        uint256 totalStrategyAssets = IStrategy(strategy).convertToAssets(strategyShares);
        uint256 currentDebt = strategies[strategy].currentDebt;
        uint256 gain;
        uint256 loss;

        if (totalStrategyAssets > currentDebt) {
            gain = totalStrategyAssets - currentDebt;
        } else {
            loss = currentDebt - totalStrategyAssets;
        }

        uint256 totalFees;
        uint256 totalRefunds;
        uint256 protocolFees;
        address protocolFeeReceipient;
        address _accountant_ = _accountant;

        if (_accountant_ != address(0)) {
            (totalFees, totalRefunds) = IAccountant(_accountant_).report(strategy, gain, loss);
            if (totalFees > 0) {
                uint16 protocolFeeBps;
                (protocolFeeBps, protocolFeeReceipient) = IFactory(factory).protocolFeeConfig();
                if (protocolFeeBps > 0) {
                    protocolFees = totalFees * protocolFeeBps / MAX_BPS;
                }
            }
        }
        uint256 sharesToBurn;
        uint256 acccountFeeShares;
        uint256 protocolFeeShares;

        if (loss + totalFees > 0) {
            sharesToBurn += _convertToShares(loss + totalFees, true);

            if (totalFees > 0) {
                acccountFeeShares = _convertToShares(totalFees - protocolFees, false);
                if (protocolFees > 0) {
                    protocolFeeShares = _convertToShares(protocolFees, false);
                }
            }
        }
        uint256 newlyLockedShares;

        if (totalRefunds > 0) {
            uint256 inter = _asset.balanceOf(_accountant_) > _asset.allowance(_accountant_, address(this))
                ? _asset.allowance(_accountant_, address(this))
                : _asset.balanceOf(_accountant_);
            totalRefunds = totalRefunds > inter ? inter : totalRefunds;
            _totalIdle += totalRefunds;
        }

        if (gain > 0) {
            strategies[strategy].currentDebt += gain;
            _totalDebt += gain;
        }

        uint256 _profitMaxUnlock = _profitMaxUnlockTime;
        if (gain + totalRefunds > 0 && _profitMaxUnlock != 0) {
            newlyLockedShares = _issueSharesForAmount(address(this), gain + totalRefunds);
        }

        if (loss > 0) {
            strategies[strategy].currentDebt -= loss;
            _totalDebt -= loss;
        }

        uint256 previouslyLockedShares = _balances[address(this)] - newlyLockedShares;

        if (sharesToBurn > 0) {
            sharesToBurn = sharesToBurn > previouslyLockedShares + newlyLockedShares
                ? previouslyLockedShares + newlyLockedShares
                : sharesToBurn;
            _burnShares(address(this), sharesToBurn);
            uint256 sharesNotToLock = sharesToBurn > newlyLockedShares ? newlyLockedShares : sharesToBurn;
            newlyLockedShares -= sharesNotToLock;
            previouslyLockedShares -= sharesToBurn - sharesNotToLock;
        }

        if (acccountFeeShares > 0) {
            _issueShares(_accountant_, acccountFeeShares);
        }

        if (protocolFeeShares > 0) {
            _issueShares(protocolFeeReceipient, protocolFeeShares);
        }

        uint256 totalLockedShares = previouslyLockedShares + newlyLockedShares;
        if (totalLockedShares > 0) {
            uint256 previouslyLockedTime;
            uint256 _fullProfitUnlockDate_ = _fullProfitUnlockDate;
            if (_fullProfitUnlockDate_ > block.timestamp) {
                previouslyLockedTime = previouslyLockedShares * (_fullProfitUnlockDate_ - block.timestamp);
            }
            uint256 newProfitLockingPeriod =
                (previouslyLockedTime + newlyLockedShares * _profitMaxUnlock) / totalLockedShares;
            _profitUnlockingRate = totalLockedShares * MAX_BPS_EXTENDED / newProfitLockingPeriod;
            _fullProfitUnlockDate = block.timestamp + newProfitLockingPeriod;
            _lastProfitUpdate = block.timestamp;
        } else {
            _profitUnlockingRate = 0;
        }

        strategies[strategy].lastReport = block.timestamp;
        return (gain, loss);
    }

    // ====================================================== \\
    //                  EXTERNAL VIEW FUNCTIONS               \\
    // ====================================================== \\

    function isShutdown() external view returns (bool) {
        return shutdown;
    }

    function unlockedShares() external view returns (uint256) {
        return _unlockedShares();
    }

    function pricePerShare() external view returns (uint256) {
        return _convertToAssets(10 ** _decimals, false);
    }

    function getDefaultQueue() external view returns (address[10] memory) {
        return _defaultQueue;
    }

    // ====================================================== \\
    //                    REPORTING MANAGEMENT                \\
    // ====================================================== \\

    function processReport(address strategy) external returns (uint256, uint256) {
        _enforeRole(msg.sender, Roles.REPORTING_MANAGER);
        return _processReport(strategy);
    }

    // function buyDebt(address strategy, uint256 amount) external {}

    function addStrategy(address newStrategy) external {
        _enforeRole(msg.sender, Roles.ADD_STRATEGY_MANAGER);
        _addStrategy(newStrategy);
    }

    function revokeStrategy(address strategy) external {
        _enforeRole(msg.sender, Roles.REVOKE_STRATEGY_MANAGER);
        _revokeStrategy(strategy, false);
    }

    function forceRevokeStrategy(address strategy) external {
        _enforeRole(msg.sender, Roles.FORCE_REVOKE_MANAGER);
        _revokeStrategy(strategy, true);
    }

    function updateMaxDebtForStrategy(address strategy, uint256 newMaxDebt) external {
        _enforeRole(msg.sender, Roles.MAX_DEBT_MANAGER);
        if (strategies[strategy].activation == 0) revert InactiveStrategy();
        strategies[strategy].maxDebt = newMaxDebt;
    }

    function updateDebt(address strategy, uint256 targetDebt) external {
        _enforeRole(msg.sender, Roles.DEBT_MANAGER);
        _updateDebt(strategy, targetDebt);
    }

    function shutdownVault() external {
        _enforeRole(msg.sender, Roles.EMERGENCY_MANAGER);
        if (shutdown) revert Shutdown();
        shutdown = true;

        if (_depositLimitModule != address(0)) {
            _depositLimitModule = address(0);
        }
        _depositLimit = 0;
        //self.roles[msg.sender] = self.roles[msg.sender] | Roles.DEBT_MANAGER
    }

    function deposit(address receiver, uint256 assets) external returns (uint256) {
        return _deposit(msg.sender, receiver, assets);
    }

    function mint(address receiver, uint256 shares) external returns (uint256) {
        return _mint(msg.sender, receiver, shares);
    }

    function withdraw(
        address receiver,
        address owner,
        uint256 assets,
        uint256 maxLoss,
        address[10] calldata _strategies
    ) external returns (uint256) {
        uint256 shares = _convertToShares(assets, true);
        return _redeem(msg.sender, receiver, owner, assets, shares, maxLoss, _strategies);
    }

    function redeem(address receiver, address owner, uint256 shares, uint256 maxLoss, address[10] calldata _strategies)
        external
        returns (uint256)
    {
        uint256 assets = _convertToAssets(shares, false);
        return _redeem(msg.sender, receiver, owner, assets, shares, maxLoss, _strategies);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        return _approve(msg.sender, spender, amount);
    }

    function transfer(address receiver, uint256 amount) external returns (bool) {
        if (receiver == address(0)) revert ZeroAddress();
        _transfer(msg.sender, receiver, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        return _transferFrom(from, to, amount);
    }

    function increaseAllowance(address spender, uint256 amount) external returns (bool) {
        return _increaseAllowance(msg.sender, spender, amount);
    }

    function decreaseAllowance(address spender, uint256 amount) external returns (bool) {
        return _decreaseAllowance(msg.sender, spender, amount);
    }

    function balanceOf(address user) external view returns (uint256) {
        return _balances[user];
    }

    function asset() external view returns (address) {
        return address(_asset);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function totalAssets() external view returns (uint256) {
        return _totalAssets();
    }

    function totalIdle() external view returns (uint256) {
        return _totalIdle;
    }

    function totalDebt() external view returns (uint256) {
        return _totalDebt;
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        return _convertToShares(assets, false);
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return _convertToShares(assets, false);
    }

    function previewMint(uint256 shares) external view returns (uint256) {
        return _convertToAssets(shares, true);
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return _convertToAssets(shares, false);
    }

    function maxDeposit(address receiver) external view returns (uint256) {
        return _maxDeposit(receiver);
    }

    function maxMint(address receiver) external view returns (uint256) {
        uint256 maxDepo = _maxDeposit(receiver);
        return _convertToShares(maxDepo, false);
    }

    function maxWithdraw(address owner, uint256 maxLoss, address[10] calldata strategy)
        external
        view
        returns (uint256)
    {
        return _maxWithdraw(owner, maxLoss, strategy);
    }

    function maxRedeem(address owner, uint256 maxLoss, address[10] calldata strategies_)
        external
        view
        returns (uint256)
    {
        uint256 shares = _convertToShares(_maxWithdraw(owner, maxLoss, strategies_), true);
        uint256 balance = _balances[owner];
        return (shares > balance ? balance : shares);
    }

    function previewWithdraw(uint256 assets) external view returns (uint256) {
        return _convertToShares(assets, false);
    }

    function previewRedeem(uint256 shares) external view returns (uint256) {
        return _convertToAssets(shares, false);
    }

    function assessShareOfUnrealizedLosses(address strategy, uint256 assetsNeeded) external view returns (uint256) {
        if (strategies[strategy].currentDebt < assetsNeeded) revert AssetsGtDebt();
        return _assessShareOfUnrealisedLosses(strategy, assetsNeeded);
    }

    function profitMaxUnlockTime() external view returns (uint256) {
        return _profitMaxUnlockTime;
    }

    function fullProfitUnlockDate() external view returns (uint256) {
        return _fullProfitUnlockDate;
    }

    function profitUnlockingRate() external view returns (uint256) {
        return _profitUnlockingRate;
    }

    function lastProfitUpdate() external view returns (uint256) {
        return _lastProfitUpdate;
    }
}
