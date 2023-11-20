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
    }
}
