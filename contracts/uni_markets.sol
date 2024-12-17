// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PredictionMarket {
    struct Market {
        string question;
        uint256 yesPool;
        uint256 noPool;
        uint256 expiryTimestamp; 
        bool resolved;
        bool outcome; 
        mapping(address => uint256) yesBets;
        mapping(address => uint256) noBets;
    }

    IERC20 public uzarToken;
    address public owner;

    Market[] public markets;

    event MarketCreated(uint256 marketId, string question, uint256 expiryTimestamp);
    event BetPlaced(uint256 marketId, address user, bool betYes, uint256 amount);
    event MarketResolved(uint256 marketId, bool outcome);
    event WinningsClaimed(uint256 marketId, address user, uint256 payout);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier marketActive(uint256 _marketId) {
        require(block.timestamp < markets[_marketId].expiryTimestamp, "Market has expired");
        require(!markets[_marketId].resolved, "Market already resolved");
        _;
    }

    constructor(address _uzarTokenAddress) {
        uzarToken = IERC20(_uzarTokenAddress);
        owner = msg.sender;
    }

    function createMarket(string memory _question, uint256 _expiryTimestamp) public onlyOwner {
        require(_expiryTimestamp > block.timestamp, "Expiration must be in the future");

        markets.push();
        Market storage newMarket = markets[markets.length - 1];
        newMarket.question = _question;
        newMarket.yesPool = 0;
        newMarket.noPool = 0;
        newMarket.expiryTimestamp = _expiryTimestamp;
        newMarket.resolved = false;
        newMarket.outcome = false;

        emit MarketCreated(markets.length - 1, _question, _expiryTimestamp);
    }

    function getMarketCount() public view returns (uint256) {
        return markets.length;
    }


    function placeBet(uint256 _marketId, bool _betYes, uint256 _amount) public marketActive(_marketId) {
        Market storage market = markets[_marketId];
        require(_amount > 0, "Bet amount must be greater than 0");

        require(uzarToken.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");

        if (_betYes) {
            market.yesBets[msg.sender] += _amount;
            market.yesPool += _amount;
        } else {
            market.noBets[msg.sender] += _amount;
            market.noPool += _amount;
        }

        emit BetPlaced(_marketId, msg.sender, _betYes, _amount);
    }

    function resolveMarket(uint256 _marketId, bool _outcome) public onlyOwner {
        Market storage market = markets[_marketId];
        require(!market.resolved, "Market already resolved");
        require(block.timestamp >= market.expiryTimestamp, "Market has not yet expired");

        market.resolved = true;
        market.outcome = _outcome;

        emit MarketResolved(_marketId, _outcome);
    }

    function claimWinnings(uint256 _marketId) public {
        Market storage market = markets[_marketId];
        require(market.resolved, "Market not resolved");

        uint256 payout;
        if (market.outcome) {
            payout = (market.yesBets[msg.sender] * market.noPool) / market.yesPool;
            market.yesBets[msg.sender] = 0;
        } else {
            payout = (market.noBets[msg.sender] * market.yesPool) / market.noPool;
            market.noBets[msg.sender] = 0;
        }

        require(payout > 0, "No winnings to claim");
        require(uzarToken.transfer(msg.sender, payout), "Token transfer failed");
        emit WinningsClaimed(_marketId, msg.sender, payout);
    }

    function getMarket(uint256 _marketId) public view returns (
        string memory,
        uint256,
        uint256,
        uint256,
        bool,
        bool
    ) {
        Market storage market = markets[_marketId];
        return (
            market.question,
            market.yesPool,
            market.noPool,
            market.expiryTimestamp,
            market.resolved,
            market.outcome
        );
    }
}


