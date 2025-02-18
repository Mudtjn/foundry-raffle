// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Events} from "test/Events.t.sol"; 

contract RaffleTest is Events, Test {
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subId;
    uint32 callbackGasLimit;
    Raffle public raffle;
    HelperConfig public helperConfig;
    address public PLAYER = makeAddr("player_1");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subId = config.subId;
        callbackGasLimit = config.callbackGasLimit;
    }

    function testRaffleInitializedInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    modifier fundPlayer() {
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        _;
    }

    modifier enterRaffle() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        _;
    }

    function testRaffleDoesNotAllowPlayerToEnterWithLessThanEntranceFee() public fundPlayer {
        uint256 playerEnteringWith = entranceFee - 1;
        vm.expectRevert(Raffle.Raffle__NotEnoughEthToEnterRaffle.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: playerEnteringWith}();
    }

    function testRaffleUpdatesPlayersWhenPlayerEnters() public fundPlayer enterRaffle {
        address playerAddress = raffle.getPlayer(0);
        assert(playerAddress == PLAYER);
    }

    function testRaffleEntryEmitsEvent() public fundPlayer {
        vm.expectEmit(address(raffle));
        emit RaffleEntered(PLAYER);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testRaffleRevertsOnEntryWhenCalculating() public fundPlayer enterRaffle {
        vm.warp(block.timestamp + interval + 1); 
        vm.roll(block.number + 1); 

        raffle.performUpkeep(""); 
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();         
    }
}
