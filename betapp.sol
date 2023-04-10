// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

contract BNBPriceBetting is KeeperCompatibleInterface {
    AggregatorV3Interface internal priceFeed;
    uint256 public lastFetchTimestamp;
    uint256 public lastPrice;
    uint256 public comparisonInterval = 30 minutes;

    enum BetDirection { UP, DOWN }
    struct Bet {
        address user;
        uint256 amount;
        uint256 price;
        BetDirection direction;
    }

    uint256 public bettingEndTime;
    uint256 public constant betAmount = 0.001 ether;
    Bet[] public bets;

    mapping(address => bool) public whitelist;

    event BetPlaced(address indexed user, uint256 amount, uint256 price, BetDirection direction);
    event Win(address indexed winner);
    event Lose(address indexed loser);

    constructor(address _priceFeedAddress) {
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
        bettingEndTime = block.timestamp + comparisonInterval / 2;
    }

    function getLatestPrice() public view returns (uint256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        require(price > 0, "Price is not valid");
        return uint256(price);
    }

    function placeBet(BetDirection direction) external payable {
        require(block.timestamp <= bettingEndTime, "Betting period is over");
        require(msg.value == betAmount, "Incorrect bet amount");

        uint256 currentPrice = getLatestPrice();
        bets.push(Bet({user: msg.sender, amount: msg.value, price: currentPrice, direction: direction}));

        emit BetPlaced(msg.sender, msg.value, currentPrice, direction);
    }

    function timeLeftToBet() public view returns (uint256) {
        if (block.timestamp > bettingEndTime) {
            return 0;
        } else {
            return bettingEndTime - block.timestamp;
        }
    }

    function checkUpkeep(bytes calldata checkData) external view override returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = (block.timestamp - lastFetchTimestamp) >= comparisonInterval;
        performData = checkData;
    }

    function performUpkeep(bytes calldata performData) external override {
        uint256 currentTimestamp = block.timestamp;
        require(currentTimestamp - lastFetchTimestamp >= comparisonInterval, "Wait for the next interval");

        uint256 currentPrice = getLatestPrice();

        if (lastFetchTimestamp != 0) {
            for (uint256 i = 0; i < bets.length; i++) {
                Bet storage bet = bets[i];
                address bettor = bet.user;
                bool won;

                if (bet.direction == BetDirection.UP) {
                    won = (currentPrice >= bet.price);
                } else if (bet.direction == BetDirection.DOWN) {
                    won = (currentPrice < bet.price);
                }

                if (won) {
                    whitelist[bettor] = true;
                    emit Win(bettor);
                } else {
                    emit Lose(bettor);
                }
            }
            delete bets; // Reset the bets array for the next round
        }

        lastFetchTimestamp = currentTimestamp;
        lastPrice = currentPrice;
        bettingEndTime = currentTimestamp + comparisonInterval / 2;
    }
}
