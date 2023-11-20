// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Gauge} from "../src/Marketplace/Gauge.sol";
import {Voter} from "../src/Marketplace/Voter.sol";
import {VotingEscrow} from "../src/Marketplace/VotingEscrow.sol";
import {GaugeFactory} from "../src/Marketplace/GaugeFactory.sol";
import {BribeFactory} from "../src/Marketplace/BribeFactory.sol";
import {VaultFactory} from "../src/Vaults/VaultFactory.sol";
import {Bribe} from "../src/Marketplace/Bribe.sol";
import {ERC20Mock} from "oz/mocks/token/ERC20Mock.sol";

contract MarketPlaceTest is Test {
    ERC20Mock public mock;
    ERC20Mock public mockReward;
    VotingEscrow public ve;
    Voter public voter;
    GaugeFactory public gaugeFactory;
    BribeFactory public bribeFactory;
    VaultFactory public factory;

    function setUp() public {
        mock = new ERC20Mock();
        mockReward = new ERC20Mock();
        gaugeFactory = new GaugeFactory();
        factory = new VaultFactory("factory", address(this), address(this));
        ve = new VotingEscrow(address(mock));
        bribeFactory = new BribeFactory(address(ve));
        voter = new Voter(address(ve), address(factory), address(gaugeFactory), address(bribeFactory));
        mock.mint(address(this), 1_000_000 ether);
    }

    // ================== Voting Escrow Tests ================== \\

    function testApprove() public {}

    function testSetTeam(address x) public {
        vm.assume(x != address(this));
        vm.prank(x);
        vm.expectRevert();
        ve.setTeam(address(0x01));
        assertEq(ve.team(), address(this));

        ve.setTeam(address(0x02));
        assertEq(ve.team(), address(0x02));
    }

    // function testGetSlope() public {}

    // function testUserHistory() public {}

    // function testLockEnd() public {}

    // function testCheckpoint() public {}

    function testDepositFor() public {
        uint256 time = 4 weeks;
        mock.approve(address(ve), type(uint256).max);
        ve.create_lock(1000 ether, time);
        ve.deposit_for(address(this), 1_000 ether);
        assertApproxEqRel(ve.balanceOfNFT(address(this)), 2_000 ether, 1 ether);
        assertApproxEqRel(ve.totalSupply(), 2_000 ether, 1 ether);
    }

    function testCreateLock() public {
        uint256 time = 4 weeks;
        mock.approve(address(ve), type(uint256).max);
        ve.create_lock(1000 ether, time);
        assertApproxEqRel(ve.balanceOfNFT(address(this)), 1_000 ether, 1 ether);
        assertApproxEqRel(ve.totalSupply(), 1_000 ether, 1 ether);
    }

    function testCreateLockFor() public {
        uint256 time = 4 weeks;
        mock.approve(address(ve), type(uint256).max);
        ve.create_lock_for(1_000 ether, time, address(0x03));
        assertApproxEqRel(ve.balanceOfNFT(address(0x03)), 1_000 ether, 1 ether);
        assertApproxEqRel(ve.totalSupply(), 1_000 ether, 1 ether);
    }

    function testIncreaseAmount() public {
        uint256 time = 1 weeks;
        mock.approve(address(ve), type(uint256).max);
        ve.create_lock_for(1_000 ether, time, address(0x03));
        uint256 end = ve.locked__end(address(0x03));
        ve.increase_amount(address(0x03), 1_000 ether);
        assertApproxEqRel(ve.balanceOfNFT(address(0x03)), 2_000 ether, 1 ether);
        assertApproxEqRel(ve.totalSupply(), 2_000 ether, 1 ether);
        assertEq(ve.locked__end(address(0x03)), end);
    }

    function testIncreaseUnlockTime() public {
        uint256 time = 1 weeks;
        mock.approve(address(ve), type(uint256).max);
        ve.create_lock(1_000 ether, time);
        uint256 end = ve.locked__end(address(this));
        ve.increase_unlock_time(address(this), 4 weeks);
        assertEq(ve.locked__end(address(this)), 4 weeks);
        assertGt(ve.locked__end(address(this)), end);
    }

    function testWithdraw() public {
        uint256 time = 1 weeks;
        mock.approve(address(ve), type(uint256).max);
        ve.create_lock(1_000 ether, time);
        uint256 pre = mock.balanceOf(address(this));
        vm.warp(2 weeks);
        ve.withdraw(address(this));
        assertEq(ve.totalSupply(), 0);
       assertEq(mock.balanceOf(address(ve)), 0);
       assertEq(mock.balanceOf(address(this)), pre + 1000 ether);
    }

    // function testBalanceOf() public {}

    // function testBalanceOfAt() public {}

    // function testTotalSupplyAt() public {}

    // function testTotalSupply() public {}

    // function testSetVoter() public {}

    // function testVoting() public {}

    // function testAbstain() public {}

    // function testAttach() public {}

    // function testDetach() public {}

    // // ====================== Voter Tests ====================== \\

    // function testInitialize() public {}

    // function testSetGov() public {}

    // function testSetCouncil() public {}

    // function testReset() public {}

    // function testPoke() public {}

    // function testVote() public {}

    // function testWhitelist() public {}

    // function testCreateGauge() public {}

    // function testKillGauge() public {}

    // function testReviveGauge() public {}

    // function testUpdates() public {}

    // function testClaimRewards() public {}

    // function testClaimBribes() public {}

    // function testDistribute() public {}

    // function testNotifyRewardsVoter() public {}

    // // ====================== Bribe Tests ====================== \\

    // function testGetReward() public {}

    // function testGetRewardForOwner() public {}

    // function testDeposit() public {}

    // function testWithdrawBribe() public {}

    // function testNotifyBribe() public {}

    // function testSwapOutReward() public {}

    // // ====================== Gauge Tests ====================== \\

    // function testGetRewardGauge() public {}

    // function testDepositGauge() public {}

    // function testWithdrawGauge() public {}

    // function testNotifyGauge() public {}

    // function testDepositForGauge() public {}
}
