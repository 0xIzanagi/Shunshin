// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Math} from "oz/utils/math/Math.sol";
import {ReentrancyGuard} from "oz/utils/ReentrancyGuard.sol";
import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "oz/token/ERC20/utils/SafeERC20.sol";
import {IVoter} from "./interfaces/IVoter.sol";

// Gauges are used to incentivize Vaults, they emit reward tokens over 7 days for vault deposits
contract Gauge is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable stakingToken;
    address public immutable rewardToken;
    address public immutable voter;

    bool public immutable isVault;

    uint256 private constant DURATION = 7 days;
    uint256 private constant PRECISION = 1e18;

    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;

    uint256 public rewardPerTokenStored;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(uint256 => uint256) public rewardRateByEpoch;

    constructor(address _stakingToken, address _rewardToken, address _voter) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        voter = _voter;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored
            + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * PRECISION) / totalSupply;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function getReward(address _account) external nonReentrant {
        address sender = msg.sender;
        if (sender != _account && sender != voter) revert NotAuthorized();

        _updateRewards(_account);

        uint256 reward = rewards[_account];
        if (reward > 0) {
            rewards[_account] = 0;
            IERC20(rewardToken).safeTransfer(_account, reward);
            emit ClaimRewards(_account, reward);
        }
    }

    function earned(address _account) public view returns (uint256) {
        return (balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / PRECISION
            + rewards[_account];
    }

    function deposit(uint256 _amount) external {
        _depositFor(_amount, msg.sender);
    }

    function deposit(uint256 _amount, address _recipient) external {
        _depositFor(_amount, _recipient);
    }

    function _depositFor(uint256 _amount, address _recipient) internal nonReentrant {
        if (_amount == 0) revert ZeroAmount();
        if (!IVoter(voter).isAlive(address(this))) revert NotAlive();

        address sender = msg.sender;
        _updateRewards(_recipient);

        IERC20(stakingToken).safeTransferFrom(sender, address(this), _amount);
        totalSupply += _amount;
        balanceOf[_recipient] += _amount;

        emit Deposit(sender, _recipient, _amount);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        address sender = msg.sender;

        _updateRewards(sender);

        totalSupply -= _amount;
        balanceOf[sender] -= _amount;
        IERC20(stakingToken).safeTransfer(sender, _amount);

        emit Withdraw(sender, _amount);
    }

    function _updateRewards(address _account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        rewards[_account] = earned(_account);
        userRewardPerTokenPaid[_account] = rewardPerTokenStored;
    }

    function left() external view returns (uint256) {
        if (block.timestamp >= periodFinish) return 0;
        uint256 _remaining = periodFinish - block.timestamp;
        return _remaining * rewardRate;
    }

    function notifyRewardAmount(uint256 _amount) external nonReentrant {
        address sender = msg.sender;
        if (sender != voter) revert NotVoter();
        if (_amount == 0) revert ZeroAmount();
        rewardPerTokenStored = rewardPerToken();
        uint256 timestamp = block.timestamp;
        uint256 timeUntilNext = _next(timestamp) - timestamp;

        if (timestamp >= periodFinish) {
            IERC20(rewardToken).safeTransferFrom(sender, address(this), _amount);
            rewardRate = _amount / timeUntilNext;
        } else {
            uint256 _remaining = periodFinish - timestamp;
            uint256 _leftover = _remaining * rewardRate;
            IERC20(rewardToken).safeTransferFrom(sender, address(this), _amount);
            rewardRate = (_amount + _leftover) / timeUntilNext;
        }
        rewardRateByEpoch[_start(timestamp)] = rewardRate;
        if (rewardRate == 0) revert ZeroRewardRate();

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        if (rewardRate > balance / timeUntilNext) revert RewardRateTooHigh();

        lastUpdateTime = timestamp;
        periodFinish = timestamp + timeUntilNext;
        emit NotifyReward(sender, _amount);
    }

    function _start(uint256 time) private pure returns (uint256) {
        unchecked {
            return time - (time % DURATION);
        }
    }

    function _next(uint256 time) private pure returns (uint256) {
        unchecked {
            return time - (time % DURATION) + DURATION;
        }
    }

    event Deposit(address indexed from, address indexed to, uint256 amount);
    event Withdraw(address indexed from, uint256 amount);
    event NotifyReward(address indexed from, uint256 amount);
    event ClaimRewards(address indexed from, uint256 amount);

    error NotAuthorized();
    error NotAlive();
    error NotVoter();
    error ZeroAmount();
    error ZeroRewardRate();
    error RewardRateTooHigh();
}
