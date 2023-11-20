// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Math} from "./libraries/Math.sol";
import {IBribe} from "./interfaces/IBribe.sol";
import {IBribeFactory} from "./interfaces/IBribeFactory.sol";
import {IGauge} from "./interfaces/IGauge.sol";
import {IGaugeFactory} from "./interfaces/IGaugeFactory.sol";
import {IERC20} from "oz/token/ERC20/IERC20.sol";
import {IFactory} from "../Vaults/interfaces/IFactory.sol";
import {IVoter} from "./interfaces/IVoter.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";

contract Voter is IVoter {
    address public immutable _ve; // the ve token that governs these .
    address public immutable factory; // the Vault Factory
    address internal immutable base;
    address public immutable gaugefactory;
    address public immutable bribefactory;
    uint256 internal constant DURATION = 7 days; // rewards are released over 7 days
    address public minter;
    address public governor; // should be set to an IGovernor
    address public emergencyCouncil; // credibly neutral party similar to Curve's Emergency DAO

    uint256 public totalWeight; // total voting weight

    address[] public vaults; // all vaults viable for incentives
    mapping(address => address) public gauges; // vault => gauge
    mapping(address => address) public vaultForGauge; // gauge => vault
    mapping(address => address) public external_bribes; // gauge => external bribe (real bribes)
    mapping(address => uint256) public weights; // vault => weight
    mapping(address => mapping(address => uint256)) public votes; // owner => vault => votes
    mapping(address => address[]) public vaultVote; // sender => vaults
    mapping(address => uint256) public usedWeights; // sender => total voting weight of user
    mapping(address => uint256) public lastVoted; // sender => timestamp of last vote, to ensure one vote per epoch
    mapping(address => bool) public isGauge;
    mapping(address => bool) public isWhitelisted;
    mapping(address => bool) public isAlive;

    event DistributeReward(address indexed caller, address gauge, uint256 claimable);
    event NotifyReward(address indexed caller, address base, uint256 amount);
    event GaugeCreated(address indexed gauge, address creator, address indexed external_bribe, address indexed pool);
    event Voted(address indexed voter, address indexed owner, uint256 weight);
    event Abstained(uint256 tokenId, uint256 weight);
    event Deposit(address indexed lp, address indexed gauge, uint256 tokenId, uint256 amount);
    event Withdraw(address indexed lp, address indexed gauge, uint256 tokenId, uint256 amount);
    event Attach(address indexed owner, address indexed gauge, uint256 tokenId);
    event Detach(address indexed owner, address indexed gauge, uint256 tokenId);
    event Whitelisted(address indexed whitelister, address indexed token);
    event Abstained(address indexed _voter, uint256 _votes);

    constructor(address __ve, address _factory, address _gauges, address _bribes) {
        _ve = __ve;
        factory = _factory;
        base = IVotingEscrow(__ve).token();
        gaugefactory = _gauges;
        bribefactory = _bribes;
        minter = msg.sender;
        governor = msg.sender;
        emergencyCouncil = msg.sender;
    }

    // simple re-entrancy check
    uint256 internal _unlocked = 1;

    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    modifier onlyNewEpoch(address _sender) {
        // ensure new epoch since last vote
        require((block.timestamp / DURATION) * DURATION > lastVoted[_sender], "TOKEN_ALREADY_VOTED_THIS_EPOCH");
        _;
    }

    function initialize(address[] memory _tokens, address _minter) external {
        require(msg.sender == minter);
        for (uint256 i = 0; i < _tokens.length; i++) {
            _whitelist(_tokens[i]);
        }
        minter = _minter;
    }

    function setGovernor(address _governor) public {
        require(msg.sender == governor);
        governor = _governor;
    }

    function setEmergencyCouncil(address _council) public {
        require(msg.sender == emergencyCouncil);
        emergencyCouncil = _council;
    }

    function reset(address _sender) external onlyNewEpoch(_sender) {
        require(IVotingEscrow(_ve).isApproved(msg.sender, _sender));
        lastVoted[_sender] = block.timestamp;
        _reset(_sender);
        IVotingEscrow(_ve).abstain(_sender);
    }

    function _reset(address _sender) internal {
        address[] storage _vaultVote = vaultVote[_sender];
        uint256 _vaultVoteCnt = _vaultVote.length;
        uint256 _totalWeight = 0;

        for (uint256 i = 0; i < _vaultVoteCnt; i++) {
            address _vault = _vaultVote[i];
            uint256 _votes = votes[_sender][_vault];

            if (_votes != 0) {
                _updateFor(gauges[_vault]);
                weights[_vault] -= _votes;
                votes[_sender][_vault] -= _votes;
                if (_votes > 0) {
                    IBribe(external_bribes[gauges[_vault]])._withdraw(uint256(_votes), _sender);
                    _totalWeight += _votes;
                } else {
                    _totalWeight -= _votes;
                }
                emit Abstained(_sender, _votes);
            }
        }
        totalWeight -= uint256(_totalWeight);
        usedWeights[_sender] = 0;
        delete vaultVote[_sender];
    }

    function poke(address _sender) external {
        address[] memory _vaultVote = vaultVote[_sender];
        uint256 _vaultCnt = _vaultVote.length;
        uint256[] memory _weights = new uint256[](_vaultCnt);

        for (uint256 i = 0; i < _vaultCnt; i++) {
            _weights[i] = votes[_sender][_vaultVote[i]];
        }

        _vote(_sender, _vaultVote, _weights);
    }

    function _vote(address _sender, address[] memory _vaultVote, uint256[] memory _weights) internal {
        _reset(_sender);
        uint256 _vaultCnt = _vaultVote.length;
        uint256 _weight = IVotingEscrow(_ve).balanceOfNFT(_sender);
        uint256 _totalVoteWeight = 0;
        uint256 _totalWeight = 0;
        uint256 _usedWeight = 0;

        for (uint256 i = 0; i < _vaultCnt; i++) {
            _totalVoteWeight += _weights[i];
        }

        for (uint256 i = 0; i < _vaultCnt; i++) {
            address _vault = _vaultVote[i];
            address _gauge = gauges[_vault];

            if (isGauge[_gauge]) {
                uint256 _vaultWeight = (_weights[i] * _weight) / _totalVoteWeight;
                require(votes[_sender][_vault] == 0);
                require(_vaultWeight != 0);
                _updateFor(_gauge);

                vaultVote[_sender].push(_vault);

                weights[_vault] += _vaultWeight;
                votes[_sender][_vault] += _vaultWeight;
                IBribe(external_bribes[_gauge])._deposit(uint256(_vaultWeight), _sender);
                _usedWeight += _vaultWeight;
                _totalWeight += _vaultWeight;
                emit Voted(msg.sender, _sender, _vaultWeight);
            }
        }
        if (_usedWeight > 0) IVotingEscrow(_ve).voting(_sender);
        totalWeight += uint256(_totalWeight);
        usedWeights[_sender] = uint256(_usedWeight);
    }

    function vote(address sender, address[] calldata _vaultVote, uint256[] calldata _weights)
        external
        onlyNewEpoch(sender)
    {
        require(IVotingEscrow(_ve).isApproved(msg.sender, sender));
        require(_vaultVote.length == _weights.length);
        lastVoted[sender] = block.timestamp;
        _vote(sender, _vaultVote, _weights);
    }

    function whitelist(address _token) public {
        require(msg.sender == governor);
        _whitelist(_token);
    }

    function _whitelist(address _token) internal {
        require(!isWhitelisted[_token]);
        isWhitelisted[_token] = true;
        emit Whitelisted(msg.sender, _token);
    }

    function createGauge(address _vault) external returns (address) {
        require(gauges[_vault] == address(0x0), "exists");
        address[] memory allowedRewards = new address[](1);
        bool isVault = IFactory(factory).isVault(_vault);

        if (isVault) {
            allowedRewards[0] = base;
        }

        if (msg.sender != governor) {
            require(isVault, "!_vault");
        }

        address _external_bribe = IBribeFactory(bribefactory).createExternalBribe(allowedRewards);
        address _gauge = IGaugeFactory(gaugefactory).createGauge(_vault, base); // Create a gauge where the vault token is the staking token and Koto is the reward

        IERC20(base).approve(_gauge, type(uint256).max);
        external_bribes[_gauge] = _external_bribe;
        gauges[_vault] = _gauge;
        vaultForGauge[_gauge] = _vault;
        isGauge[_gauge] = true;
        isAlive[_gauge] = true;
        _updateFor(_gauge);
        vaults.push(_vault);
        emit GaugeCreated(_gauge, msg.sender, _external_bribe, _vault);
        return _gauge;
    }

    function killGauge(address _gauge) external {
        require(msg.sender == emergencyCouncil, "not emergency council");
        require(isAlive[_gauge], "gauge already dead");
        isAlive[_gauge] = false;
        claimable[_gauge] = 0;
        //emit GaugeKilled(_gauge);
    }

    function reviveGauge(address _gauge) external {
        require(msg.sender == emergencyCouncil, "not emergency council");
        require(!isAlive[_gauge], "gauge already alive");
        isAlive[_gauge] = true;
        //emit GaugeRevived(_gauge);
    }

    function length() external view returns (uint256) {
        return vaults.length;
    }

    uint256 internal index;
    mapping(address => uint256) internal supplyIndex;
    mapping(address => uint256) public claimable;

    function notifyRewardAmount(uint256 amount) external {
        _safeTransferFrom(base, msg.sender, address(this), amount); // transfer the distro in
        uint256 _ratio = (amount * 1e18) / totalWeight; // 1e18 adjustment is removed during claim
        if (_ratio > 0) {
            index += _ratio;
        }
        emit NotifyReward(msg.sender, base, amount);
    }

    function updateFor(address[] memory _gauges) external {
        for (uint256 i = 0; i < _gauges.length; i++) {
            _updateFor(_gauges[i]);
        }
    }

    function updateForRange(uint256 start, uint256 end) public {
        for (uint256 i = start; i < end; i++) {
            _updateFor(gauges[vaults[i]]);
        }
    }

    function updateAll() external {
        updateForRange(0, vaults.length);
    }

    function updateGauge(address _gauge) external {
        _updateFor(_gauge);
    }

    function _updateFor(address _gauge) internal {
        address _vault = vaultForGauge[_gauge];
        uint256 _supplied = weights[_vault];
        if (_supplied > 0) {
            uint256 _supplyIndex = supplyIndex[_gauge];
            uint256 _index = index; // get global index0 for accumulated distro
            supplyIndex[_gauge] = _index; // update _gauge current position to global position
            uint256 _delta = _index - _supplyIndex; // see if there is any difference that need to be accrued
            if (_delta > 0) {
                uint256 _share = (uint256(_supplied) * _delta) / 1e18; // add accrued difference for each supplied token
                if (isAlive[_gauge]) {
                    claimable[_gauge] += _share;
                }
            }
        } else {
            supplyIndex[_gauge] = index; // new users are set to the default global state
        }
    }

    function claimRewards(address[] memory _gauges) external {
        for (uint256 i = 0; i < _gauges.length; i++) {
            IGauge(_gauges[i]).getReward(msg.sender);
        }
    }

    function claimBribes(address[] memory _bribes, address[][] memory _tokens, address _owner) external {
        require(IVotingEscrow(_ve).isApproved(msg.sender, _owner));
        for (uint256 i = 0; i < _bribes.length; i++) {
            IBribe(_bribes[i]).getRewardForOwner(_owner, _tokens[i]);
        }
    }

    function distribute(address _gauge) public lock {
        _updateFor(_gauge); // should set claimable to 0 if killed
        uint256 _claimable = claimable[_gauge];
        if (_claimable > IGauge(_gauge).left() && _claimable / DURATION > 0) {
            claimable[_gauge] = 0;
            IGauge(_gauge).notifyRewardAmount(_claimable);
            emit DistributeReward(msg.sender, _gauge, _claimable);
        }
    }

    function distro() external {
        distribute(0, vaults.length);
    }

    function distribute() external {
        distribute(0, vaults.length);
    }

    function distribute(uint256 start, uint256 finish) public {
        for (uint256 x = start; x < finish; x++) {
            distribute(gauges[vaults[x]]);
        }
    }

    function distribute(address[] memory _gauges) external {
        for (uint256 x = 0; x < _gauges.length; x++) {
            distribute(_gauges[x]);
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }
}
