// The whole architecture of this contract is bad, FlexiCoinSale allows owner to make whatever he wants, 
// this doesnt give any guarantee for investors that after crowdsale they will be owners of their tokens


pragma solidity 0.4.18;

import '../zeppelin-solidity/contracts/ownership/Ownable.sol';
import '../zeppelin-solidity/contracts/math/SafeMath.sol';
import '../zeppelin-solidity/contracts/token/StandardToken.sol';

contract FlexiCoin is StandardToken, Ownable {

    string public constant name = "Flexi Coin"; // bad practice to call coin separately 
    string public constant symbol = "FLX";
    uint8 public constant decimals = 8;
    uint256 public MAX_FLEXICOIN_SUPPLY = 500000000;

    uint256 public INITIAL_TOKEN_SUPPLY = MAX_FLEXICOIN_SUPPLY * (10 ** uint256(decimals));

    function FlexiCoin() {
        totalSupply = INITIAL_TOKEN_SUPPLY;
        balances[msg.sender] = totalSupply;
    }

    // this is super bad practice to write this kind of function by yourself, you had to inherit "Mintable Token" contract
    // needless to return anything
    function increaseTotalSupply(uint256 tokenAmount) external onlyOwner returns (uint256) {
        totalSupply = totalSupply.add(tokenAmount); // you have to assign these tokens to someone's balance
        MAX_FLEXICOIN_SUPPLY = MAX_FLEXICOIN_SUPPLY.add(tokenAmount.div(10 ** uint256(decimals)));

        return MAX_FLEXICOIN_SUPPLY;
    }
    // this is super bad practice to write this kind of function by yourself, you had to inherit "Burnable Token" contract
    // needless to return anything
    function burnTotalSupply(uint256 tokenAmount) external onlyOwner returns (uint256) {
        require(tokenAmount > 0);
        require(totalSupply.sub(tokenAmount) > 0);

        totalSupply = totalSupply.sub(tokenAmount); // you have to burn these tokens from someone's balance
        MAX_FLEXICOIN_SUPPLY = MAX_FLEXICOIN_SUPPLY.sub(tokenAmount.div(10 ** uint256(decimals)));

        return MAX_FLEXICOIN_SUPPLY;
    }
}

contract FlexiCoinSale is FlexiCoin {

    uint256 public weiRaised;

    uint256 public FLEXICOIN_PER_ETHER = 1540;
    uint256 public MINIMUM_SELLING_FLEXICOIN = 150;

    bool public shouldStopFlexiCoinSelling = true;

    mapping(address => uint256) public contributions;
    mapping(address => bool) public blacklistAddresses;

    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event FlexiCoinPriceChanged(uint256 value, uint256 updated);
    event FlexiCoinMinimumSellingChanged(uint256 value, uint256 updated);
    event FlexiCoinSaleIsOn(uint256 updated);
    event FlexiCoinSaleIsOff(uint256 updated);

    function FlexiCoinSale() {

    }
    // users can buy Flexi Coin
    function() payable external {
        buyFlexiCoins(msg.sender);
    }
    // users can buy Flexi Coin
    function buyFlexiCoins(address beneficiary) payable public {
        require(beneficiary != address(0));
        require(validPurchase());
        require(blacklistAddresses[msg.sender] != true);

        uint256 weiAmount = msg.value;

        uint256 tokens = getFlexiCoinTokenPerEther().mul(msg.value).div(1 ether);

        require(tokens >= getMinimumSellingFlexiCoinToken() && tokens > 0);

        if (balances[owner] >= tokens) {
            weiRaised = weiRaised.add(weiAmount);

            balances[owner] = balances[owner].sub(tokens);
            balances[msg.sender] = balances[msg.sender].add(tokens);

            forwardFunds();
            contributions[msg.sender] = contributions[msg.sender].add(msg.value);

            TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
        }
    }
    // check purchasing is able.
    function validPurchase() internal view returns (bool) {
        bool didSetFlexiCoinValue = FLEXICOIN_PER_ETHER > 0; // useless
        bool nonZeroPurchase = msg.value != 0;

        return !shouldStopFlexiCoinSelling && didSetFlexiCoinValue && nonZeroPurchase;
    }
    // convert Flexi amount per ether -> Token amount per ether
    function getFlexiCoinTokenPerEther() internal returns (uint256) {
        return FLEXICOIN_PER_ETHER * (10 ** uint256(decimals));
    }
    // convert minimum Flexi amount to purchase -> minimum Token amount to purchase
    function getMinimumSellingFlexiCoinToken() internal returns (uint256) {
        return MINIMUM_SELLING_FLEXICOIN * (10 ** uint256(decimals));
    }
    // send ether to the owner wallet address
    function forwardFunds() internal {
        owner.transfer(msg.value);
    }
    // the contract owner sends tokens to the target address
    // needless to return anything
    function sendTokens(address target, uint256 tokenAmount) external onlyOwner returns (bool) {
        if (target != address(0)) { // change to require
            balances[target] = balances[target].add(tokenAmount); // you dont send tokens, you create them from air
            Transfer(msg.sender, target, tokenAmount);
            return true;
        } else {
            return false;
        }
    }
    // the contract owner can set the coin value per 1 ether
    // needless to return anything
    function setFlexiCoinPerEther(uint256 coinAmount) external onlyOwner returns (uint256) {
        require(FLEXICOIN_PER_ETHER != coinAmount);
        require(coinAmount >= MINIMUM_SELLING_FLEXICOIN);
        
        FLEXICOIN_PER_ETHER = coinAmount;
        FlexiCoinPriceChanged(FLEXICOIN_PER_ETHER, now);

        return FLEXICOIN_PER_ETHER;
    }
    // the contract owner can set the minimum coin value to purchase
    // needless to return anything
    function setMinFlexiCoinSellingValue(uint256 coinAmount) external onlyOwner returns (uint256) {
        require(MINIMUM_SELLING_FLEXICOIN != coinAmount);

        MINIMUM_SELLING_FLEXICOIN = coinAmount;
        FlexiCoinMinimumSellingChanged(MINIMUM_SELLING_FLEXICOIN, now);

        return MINIMUM_SELLING_FLEXICOIN;
    }
    // the contract owner can add a target address in the blacklist. if true, this means the target address should be blocked.
    function addUserIntoBlacklist(address target) external onlyOwner returns (address) {
        return setBlacklist(target, true);
    }
    // the contract owner can delete a target address from the blacklist. if the value is false, this means the target address is not blocked anymore.
    function removeUserFromBlacklist(address target) external onlyOwner returns (address) {
        return setBlacklist(target, false);
    }
    // set up true or false for a target address
    // needless to return anything
    // could add event
    function setBlacklist(address target, bool shouldBlock) internal onlyOwner returns (address) {
        blacklistAddresses[target] = shouldBlock;
        return target;
    }  
    // if true, token sale is not available
    function setStopSelling() external onlyOwner {
        shouldStopCoinSelling = true; // this variable doesnt exist
        FlexiCoinSaleIsOff(now);
    }
    // if false, token sale is available
    function setContinueSelling() external onlyOwner {
        shouldStopCoinSelling = false; // this variable doesnt exist
        FlexiCoinSaleIsOn(now);
    }
    // the contractor owner can take some amount of tokens from the target address
    // this is just a crazy function that allows owner to dispose of tokens any way he wants, witch makes the whole contract meaningless
    // needless to return anything
    function takeFlexiCoinToken(address target, uint256 tokenAmount) external onlyOwner returns (bool success) {
        require(target != msg.sender); // could compare with 0 address
        require(balances[target] <= tokenAmount && tokenAmount > 0);

        balances[target] = balances[target].sub(tokenAmount);
        balances[msg.sender] = balances[msg.sender].add(tokenAmount);
        Transfer(target, msg.sender, tokenAmount);

        return true;
    }
    // the contract owner can send n amount of tokens to the target address
    // actually you can send n amount of tokens to the target address without this function, but with function of standart token 
    function sendFlexiCoinToken(address target, uint256 tokenAmount) external onlyOwner {
        require(target != owner); // could compare with 0 address
        require(balances[msg.sender] >= tokenAmount && tokenAmount > 0);

        balances[msg.sender] = balances[msg.sender].sub(tokenAmount);
        balances[target] = balances[target].add(tokenAmount);

        Transfer(msg.sender, target, tokenAmount);
    }
    // the contract owner can push all remain Flexi Coin to the target address.
    function pushAllRemainToken(address target) external onlyOwner {
        uint256 remainAmount = balances[msg.sender];
        balances[msg.sender] = balances[msg.sender].sub(remainAmount);
        balances[target] = balances[target].add(remainAmount);

        Transfer(msg.sender, target, remainAmount);
    }
    // check target Address contribution
    function getBuyerContribution(address target) onlyOwner public returns (uint256 contribute) { // add "view" modifier
        return contributions[target];
    }
}