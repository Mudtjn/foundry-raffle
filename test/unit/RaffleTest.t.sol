// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console, console2} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Events} from "test/Events.t.sol"; 
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

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
        console.log("Helper config is ", config.vrfCoordinator); 
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

    /////////////////////////////// CHECKUPKEEP TESTS /////////////////////////////////
    function testCheckupkeepReturnsReturnsFalseOnNoTimePassed() public fundPlayer enterRaffle {
        (bool upkeepNeeded, ) = raffle.checkUpkeep(""); 
        assert(!upkeepNeeded); 
    }

    function testCheckupkeepReturnsReturnsFalseOnRaffleClosed() public fundPlayer enterRaffle {
        vm.warp(block.timestamp + interval + 1); 
        vm.roll(block.number + 1); 
        raffle.performUpkeep(""); 

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckupkeepReturnsReturnsFalseOnNoPlayersInRaffle() public {
        vm.warp(block.timestamp + interval + 1); 
        vm.roll(block.number + 1); 

        (bool upkeepNeeded, ) = raffle.checkUpkeep(""); 
        assert(!upkeepNeeded); 
    }

    ////////////////////////////// PERFORMUPKEEP TESTS /////////////////////////////////
    function testRaffleRevertsWhenUpTimeNotPassed() public fundPlayer enterRaffle {
        uint256 balance = address(raffle).balance;
        uint256 totalParticipants = 1; 
        Raffle.RaffleState state = Raffle.RaffleState.OPEN;
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, balance, totalParticipants, state));
        raffle.performUpkeep("");         
    }

    function testRaffleRevertsWhenRaffleNotOpen() public fundPlayer enterRaffle {
        vm.warp(block.timestamp + interval + 1); 
        vm.roll(block.number + 1); 
        raffle.performUpkeep(""); 
    
        uint256 balance = address(raffle).balance;
        uint256 totalParticipants = 1; 
        Raffle.RaffleState state = Raffle.RaffleState.CALCULATING;
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, balance, totalParticipants, state));
        raffle.performUpkeep(""); 
    }

    function testRaffleRevertsWhenNoPlayerInRaffle() public {
        vm.warp(block.timestamp + interval + 1); 
        vm.roll(block.number + 1); 

        uint256 balance = address(raffle).balance;
        uint256 totalParticipants = 0; 
        Raffle.RaffleState state = Raffle.RaffleState.OPEN;
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, balance, totalParticipants, state));
        raffle.performUpkeep("");       
    }

    function testPerformUpkeepUpdatesRaffleAndEmitsEvent() fundPlayer public {
        vm.prank(PLAYER); 
        raffle.enterRaffle{value: entranceFee}(); 
        vm.warp(block.timestamp + interval + 1); 
        vm.roll(block.number + 1); 

        vm.recordLogs(); 
        raffle.performUpkeep(""); 
        Vm.Log[] memory entries = vm.getRecordedLogs(); 
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState(); 
        console.log("Request id is : ", uint256(requestId)); 
        assert(uint256(requestId) > 0); 
        assert(raffleState == Raffle.RaffleState.CALCULATING);         
    }

    //////////////////////////// fulfill random words /////////////////////////////
    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }


    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 requestId) public fundPlayer raffleEntered {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector); 
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
    }

    function testFulfillRandomWordsPicksWinnerAndSendsMoney() fundPlayer raffleEntered public {
        address expectedWinner = address(1);

        uint256 additionalEntrants = 3; 
        uint256 startingIndex = 1; 

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimestamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs
        assert(vrfCoordinator == helperConfig.getConfig().vrfCoordinator);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimestamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
