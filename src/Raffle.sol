// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

//SPDX-License-Identifier：MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";//interface with VRF

/**
 * @title A sample Raffle Contract
 * @author Rafer
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    error Raffle_NotEnoughEthSent();
    error Raffle_TransferFaild();
    error Raffle_RaffleNotOpen();
    error Raffle_UpKeepNoNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

    //bool lotteryState = open, closed, calcualting
    /* Type decalarations */
    enum RaffleState {
        OPEN, //0
        CALCULATING //1
    }

    /**State variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;//duration in seconds
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gaslane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /**Events */
    event RaffleEnter(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    /* Functions */
    constructor(
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gaslane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() external payable{
       // require(msg.value >= i_entranceFee, "Not enought ETH sent");
       if(msg.value < i_entranceFee){
          revert Raffle_NotEnoughEthSent();
       }
       if(s_raffleState != RaffleState.OPEN) {
          revert Raffle_RaffleNotOpen();
       }
       s_players.push(payable(msg.sender));//payable to allow address to get eth
       emit RaffleEnter(msg.sender);
    }
    
    //when is winner supposed to be picked
    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open state.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     */
     function checkUpkeep(bytes memory /* checkData */) public view
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
        return (upkeepNeeded, "0X0");//0x0 is placeholder
    }
    
    //1.get a random number
    //2.ues the random number to pick a player
    //3.be automatically called
    function performUpkeep(bytes calldata /* performData */) external{
        (bool upkeepNeed, ) = checkUpkeep("");
        if(!upkeepNeed) {
            revert Raffle_UpKeepNoNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        //check to see if enough time has passed
        if((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert(); 
        }
        //use vrf
        //1.request the RNG
        //2.Get the random number
        // Will revert if subscription is not set and funded.
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gaslane,//gas lane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,//number of block confirmation to wait
            i_callbackGasLimit,//to make sure not overspend
            NUM_WORDS 
        );
        //actually its redundant,cuz vrfMock's request random words already have
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(//to make a new random number by 2 parameters
        uint256 /*requestId*/,
        uint256[] memory randomWords
    )internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;//check 
        s_raffleState = RaffleState.OPEN;
        //reset array to start new raffle
        s_players = new address payable[](0);//clear
        s_lastTimeStamp = block.timestamp;

        (bool success,) = winner.call{value: address(this).balance}("");
        if(!success) {
            revert Raffle_TransferFaild();
        }
        emit PickedWinner(winner);
    }

    //Getter function
     function getEntranceFee() external view returns(uint256) {
        return i_entranceFee;
    }

   function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns(address) {
        return s_players[indexOfPlayer];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getLenthOfPlayers() external view returns(uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns(uint256) {
        return s_lastTimeStamp;
    }
 }