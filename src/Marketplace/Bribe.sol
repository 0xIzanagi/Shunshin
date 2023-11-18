// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Math} from "./libraries/Math.sol";
import {IBribe} from "./interfaces/IBribe.sol";
import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {IGauge} from "./interfaces/IGauge.sol";
import {IVoter} from "./interfaces/IVoter.sol";
import "./interfaces/IVotingEscrow.sol";

// Bribes pay out rewards for a given vault based on the votes that were received from the user (goes hand in hand with Voter.vote())
contract Bribe is IBribe {
    address public immutable voter; // only voter can modify balances (since it only happens on vote())
    address public immutable _ve;
    uint256 internal constant DURATION = 7 days; // rewards are released over the voting period
    uint256 internal constant MAX_REWARD_TOKENS = 16;

    uint256 internal constant PRECISION = 10 ** 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(uint256 => uint256)) public tokenRewardsPerEpoch;
    mapping(address => uint256) public periodFinish;
    mapping(address => mapping(address => uint256)) public lastEarn;

    address[] public rewards;
    mapping(address => bool) public isReward;

    /// @notice A checkpoint for marking balance
    struct Checkpoint {
        uint256 timestamp;
        uint256 balanceOf;
    }

    /// @notice A checkpoint for marking supply
    struct SupplyCheckpoint {
        uint256 timestamp;
        uint256 supply;
    }

    /// @notice A record of balance checkpoints for each account, by index
    mapping(address => mapping(uint256 => Checkpoint)) public checkpoints;
    /// @notice The number of checkpoints for each account
    mapping(address => uint256) public numCheckpoints;
    /// @notice A record of balance checkpoints for each token, by index
    mapping(uint256 => SupplyCheckpoint) public supplyCheckpoints;
    /// @notice The number of checkpoints
    uint256 public supplyNumCheckpoints;

    event Deposit(address indexed from, address sender, uint256 amount);
    event Withdraw(address indexed from, address sender, uint256 amount);
    event NotifyReward(address indexed from, address indexed reward, uint256 epoch, uint256 amount);
    event ClaimRewards(address indexed from, address indexed reward, uint256 amount);

    constructor(address _voter, address _votingEscrow, address[] memory _allowedRewardTokens) {
        voter = _voter;
        _ve = _votingEscrow;
        for (uint256 i; i < _allowedRewardTokens.length; i++) {
            if (_allowedRewardTokens[i] != address(0)) {
                isReward[_allowedRewardTokens[i]] = true;
                rewards.push(_allowedRewardTokens[i]);
            }
        }
    }

    // simple re-entrancy check
    uint256 internal _unlocked = 1;

    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    function _bribeStart(uint256 timestamp) internal pure returns (uint256) {
        return timestamp - (timestamp % DURATION);
    }

    function getEpochStart(uint256 timestamp) public pure returns (uint256) {
        uint256 bribeStart = _bribeStart(timestamp);
        uint256 bribeEnd = bribeStart + DURATION;
        return timestamp < bribeEnd ? bribeStart : bribeStart + DURATION;
    }

    /**
     * @notice Determine the prior balance for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param sender address of the user to check
     * @param timestamp The timestamp to get the balance at
     * @return The balance the account had as of the given block
     */
    function getPriorBalanceIndex(address sender, uint256 timestamp) public view returns (uint256) {
        uint256 nCheckpoints = numCheckpoints[sender];
        if (nCheckpoints == 0) {
            return 0;
        }
        // First check most recent balance
        if (checkpoints[sender][nCheckpoints - 1].timestamp <= timestamp) {
            return (nCheckpoints - 1);
        }
        // Next check implicit zero balance
        if (checkpoints[sender][0].timestamp > timestamp) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[sender][center];
            if (cp.timestamp == timestamp) {
                return center;
            } else if (cp.timestamp < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return lower;
    }

    function getPriorSupplyIndex(uint256 timestamp) public view returns (uint256) {
        uint256 nCheckpoints = supplyNumCheckpoints;
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (supplyCheckpoints[nCheckpoints - 1].timestamp <= timestamp) {
            return (nCheckpoints - 1);
        }

        // Next check implicit zero balance
        if (supplyCheckpoints[0].timestamp > timestamp) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            SupplyCheckpoint memory cp = supplyCheckpoints[center];
            if (cp.timestamp == timestamp) {
                return center;
            } else if (cp.timestamp < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return lower;
    }

    function _writeCheckpoint(address sender, uint256 balance) internal {
        uint256 _timestamp = block.timestamp;
        uint256 _nCheckPoints = numCheckpoints[sender];
        if (_nCheckPoints > 0 && checkpoints[sender][_nCheckPoints - 1].timestamp == _timestamp) {
            checkpoints[sender][_nCheckPoints - 1].balanceOf = balance;
        } else {
            checkpoints[sender][_nCheckPoints] = Checkpoint(_timestamp, balance);
            numCheckpoints[sender] = _nCheckPoints + 1;
        }
    }

    function _writeSupplyCheckpoint() internal {
        uint256 _nCheckPoints = supplyNumCheckpoints;
        uint256 _timestamp = block.timestamp;

        if (_nCheckPoints > 0 && supplyCheckpoints[_nCheckPoints - 1].timestamp == _timestamp) {
            supplyCheckpoints[_nCheckPoints - 1].supply = totalSupply;
        } else {
            supplyCheckpoints[_nCheckPoints] = SupplyCheckpoint(_timestamp, totalSupply);
            supplyNumCheckpoints = _nCheckPoints + 1;
        }
    }

    function rewardsListLength() external view returns (uint256) {
        return rewards.length;
    }

    // returns the last time the reward was modified or periodFinish if the reward has ended
    function lastTimeRewardApplicable(address token) public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish[token]);
    }

    // allows a user to claim rewards for a given token
    function getReward(address sender, address[] memory tokens) external lock {
        if (msg.sender != sender) {
            if (!IVotingEscrow(_ve).isApproved(sender, msg.sender)) revert NotApproved();
        }
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 _reward = earned(tokens[i], sender);
            lastEarn[tokens[i]][sender] = block.timestamp;
            if (_reward > 0) _safeTransfer(tokens[i], msg.sender, _reward);

            emit ClaimRewards(msg.sender, tokens[i], _reward);
        }
    }

    // used by Voter to allow batched reward claims
    function getRewardForOwner(address sender, address[] memory tokens) external lock {
        require(msg.sender == voter);
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 _reward = earned(tokens[i], sender);
            lastEarn[tokens[i]][sender] = block.timestamp;
            if (_reward > 0) _safeTransfer(tokens[i], sender, _reward);

            emit ClaimRewards(sender, tokens[i], _reward);
        }
    }

    function earned(address token, address sender) public view returns (uint256) {
        uint256 _startTimestamp = lastEarn[token][sender];
        if (numCheckpoints[sender] == 0) {
            return 0;
        }

        uint256 _startIndex = getPriorBalanceIndex(sender, _startTimestamp);
        uint256 _endIndex = numCheckpoints[sender] - 1;

        uint256 reward = 0;
        // you only earn once per epoch (after it's over)
        Checkpoint memory prevRewards; // reuse struct to avoid stack too deep
        prevRewards.timestamp = _bribeStart(_startTimestamp);
        uint256 _prevSupply = 1;

        if (_endIndex > 0) {
            for (uint256 i = _startIndex; i <= _endIndex - 1; i++) {
                Checkpoint memory cp0 = checkpoints[sender][i];
                uint256 _nextEpochStart = _bribeStart(cp0.timestamp);
                // check that you've earned it
                // this won't happen until a week has passed
                if (_nextEpochStart > prevRewards.timestamp) {
                    reward += prevRewards.balanceOf;
                }

                prevRewards.timestamp = _nextEpochStart;
                _prevSupply = supplyCheckpoints[getPriorSupplyIndex(_nextEpochStart + DURATION)].supply;
                prevRewards.balanceOf = (cp0.balanceOf * tokenRewardsPerEpoch[token][_nextEpochStart]) / _prevSupply;
            }
        }

        Checkpoint memory cp = checkpoints[sender][_endIndex];
        uint256 _lastEpochStart = _bribeStart(cp.timestamp);
        uint256 _lastEpochEnd = _lastEpochStart + DURATION;

        if (block.timestamp > _lastEpochEnd) {
            reward += (cp.balanceOf * tokenRewardsPerEpoch[token][_lastEpochStart])
                / supplyCheckpoints[getPriorSupplyIndex(_lastEpochEnd)].supply;
        }

        return reward;
    }

    // This is an external function, but internal notation is used since it can only be called "internally" from Gauges
    function _deposit(uint256 amount, address sender) external {
        require(msg.sender == voter);

        totalSupply += amount;
        balanceOf[sender] += amount;

        _writeCheckpoint(sender, balanceOf[sender]);
        _writeSupplyCheckpoint();

        emit Deposit(msg.sender, sender, amount);
    }

    function _withdraw(uint256 amount, address sender) external {
        require(msg.sender == voter);

        totalSupply -= amount;
        balanceOf[sender] -= amount;

        _writeCheckpoint(sender, balanceOf[sender]);
        _writeSupplyCheckpoint();

        emit Withdraw(msg.sender, sender, amount);
    }

    function left(address token) external view returns (uint256) {
        uint256 adjustedTstamp = getEpochStart(block.timestamp);
        return tokenRewardsPerEpoch[token][adjustedTstamp];
    }

    function notifyRewardAmount(address token, uint256 amount) external lock {
        require(amount > 0);
        if (!isReward[token]) {
            require(IVoter(voter).isWhitelisted(token), "bribe tokens must be whitelisted");
            require(rewards.length < MAX_REWARD_TOKENS, "too many rewards tokens");
        }
        // bribes kick in at the start of next bribe period
        uint256 adjustedTstamp = getEpochStart(block.timestamp);
        uint256 epochRewards = tokenRewardsPerEpoch[token][adjustedTstamp];

        _safeTransferFrom(token, msg.sender, address(this), amount);
        tokenRewardsPerEpoch[token][adjustedTstamp] = epochRewards + amount;

        periodFinish[token] = adjustedTstamp + DURATION;

        if (!isReward[token]) {
            isReward[token] = true;
            rewards.push(token);
        }

        emit NotifyReward(msg.sender, token, adjustedTstamp, amount);
    }

    function swapOutRewardToken(uint256 i, address oldToken, address newToken) external {
        //require(msg.sender == IVotingEscrow(_ve).team(), "only team");
        require(rewards[i] == oldToken);
        isReward[oldToken] = false;
        isReward[newToken] = true;
        rewards[i] = newToken;
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    error NotApproved();
}
