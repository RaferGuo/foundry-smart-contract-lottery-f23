//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import{DeployRaffle} from "../../script/DeployRaffle.s.sol";
import{Raffle} from "../../src/Raffle.sol";
import{Test, console} from "forge-std/Test.sol";
//get the stuff from Helperconfig 
import{HelperConfig} from "../../script/HelperConfig.s.sol";
import{Vm} from "forge-std/Vm.sol";
import{VRFCoordinatorV2Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract  RaffleTest is Test{
     /*Events */
     //event RaffleEnter(address indexed player);
     event RaffleEnter(address indexed player);

     Raffle raffle;
     HelperConfig helperConfig; 
     
     uint64 subscriptionId;
     bytes32 gasLane;
     uint256 interval;
     uint256 entranceFee;
     uint32 callbackGasLimit;
     address vrfCoordinator;
     address link;

     address public PLAYER = makeAddr("player");
     uint256 public constant STARTING_USER_BALANCE = 10 ether;

     function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
        subscriptionId,
        gasLane,// keyHash
        interval,
        entranceFee,
        callbackGasLimit,
        vrfCoordinator,
        link,
         ) = helperConfig.activeNetworkConfig();
         vm.deal(PLAYER, STARTING_USER_BALANCE);
     }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }
    
    /////////////////////////
    //enterRaffle function //
    function testRaffleRevertsWhenYouDontPayEnough() public {
        //Arrange
        vm.prank(PLAYER);
        //Act   //Asserts
        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address palyerRecorded = raffle.getPlayer(0);
        assert(palyerRecorded == PLAYER);
    }

     function testEmitsEventOnEntrance() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEnter(PLAYER);//cant use name EnteredRaffle here, dont know why
        raffle.enterRaffle{value: entranceFee}();
    }

    // function testCanEnterWhenRaffleIsCalculating() public {
    //     vm.prank(PLAYER);
    //     raffle.enterRaffle{value: entranceFee};
    //     //+1 to make sure absolutely over the interval;
    //     vm.warp(block.timestamp + interval + 1);
    //     //dont have to +1,but like to do it;
    //     vm.roll(block.number + 1);
    //     //should be in calculate states
    //     raffle.performUpkeep("");
    //     vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
    //     //next real call will be pretended to be with the player
    //     vm.prank(PLAYER);
    //     raffle.enterRaffle{value: entranceFee}();
    // }

    ////////////////////////
    //checkUpkeep     //
    ///////////////////////
    function testCheckUpkeepReturnsFalseIfIthasNobalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //assert
        assert(!upkeepNeeded);//assert not false;
    }

    //testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
         //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }


    //testCheckUpkeepReturnsTruthWhenParametersAreGood\
    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    /////////////////////
    // performUpkeep   //
    /////////////////////
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        //Arrange
        uint256 balance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        //ACT/ASSETY
        //vm.expectRevert(abi.encodeWithSelector(CustomError.selector,1,2))
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle_UpKeepNoNeeded.selector, balance, numPlayers, raffleState));
        //next transaction will fail
        raffle.performUpkeep("");
    }

    modifier RaffleEnteredAndTimePassed {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    //what if ineed to test using the output of an event?
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequest() public RaffleEnteredAndTimePassed{
        //Act
        vm.recordLogs();
        raffle.performUpkeep("");//emit requestId
        //get all of the values of all of the event we emit
        Vm.Log[]  memory entries = vm.getRecordedLogs();
        //encode[0] will be requestRandomWords
        bytes32 requestId = entries[1].topics[1];//topics[0] is whole event,1 is requestId

        Raffle.RaffleState rState = raffle.getRaffleState();

        //make sure requestId was generated
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    ////////////////////////////
    ///// fulfillRandomWords ///
    ////////////////////////////
    modifier SkipFork {
        if(block.chainid != 31337) {
           return;
        }
        _;
    }

    function testfulfillRandomWordsCanOnlyBeCalledAfterPerformUpCheck(uint256 randomRequestId) public RaffleEnteredAndTimePassed SkipFork{
        //Arrange
        vm.expectRevert("nonexistent request");
        //only fake evironment can call this,cuz vrf only exist here
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    } 

    function testfulfillRandomWordsPicksAWinnerResetsAndSendMoney() public RaffleEnteredAndTimePassed SkipFork{
        //Arrange
        //already have 1 in raffle
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for(uint256 i = startingIndex; i< startingIndex + additionalEntrants; i++) {
            address player = address(uint160(i));//address(1,2...);
            hoax(player, 10 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        //the consumer is raffle contract 
        vm.recordLogs();
        raffle.performUpkeep("");//emit requestId
        //get all of the values of all of the event we emit
        Vm.Log[]  memory entries = vm.getRecordedLogs();
        //encode[0] will be requestRandomWords
        bytes32 requestId = entries[1].topics[1];//topics[0] is whole event,1 is requestId
        uint256 previousTimeStamp = raffle.getLastTimeStamp();
        
        //pretend to be chainlink vrf to get random number & pick winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        //assert
        //default have those data
        assert(uint256(raffle.getRaffleState()) == 0);//state is open
        // //should have winner
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLenthOfPlayers() == 0);//sure clear the s_players;
        assert(raffle.getLastTimeStamp() > previousTimeStamp); 
        console.log(raffle.getRecentWinner().balance);
        // 10050000000000000000
        console.log(STARTING_USER_BALANCE + prize - entranceFee);
        assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE + prize - entranceFee);//entranceFee is paid to be part of it;
    }
}