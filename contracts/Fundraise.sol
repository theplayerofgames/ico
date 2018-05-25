pragma solidity ^0.4.22;

contract Fundraise {
  using SafeMath for uint256;

  // The support commitment/unitized invoice (UPC) on offer
  MintableUPC public unitizedProofOfContribution;

  // start and end timestamps where support commitments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  // address where support commitments are collected
  address public wallet;

  // how many unitized invoices (UPC) a patron gets per wei
  uint256 public rate;

  // amount of support commitment gathered in wei
  uint256 public weiRaised;

  /**
   * event for transference process logging
   * @param patron who provided support commitment for unitized invoices (UPC)
   * @param patron who got the unitized invoices (UPC)
   * @param value weis contributed for unitized invoice (UPC) transfer
   * @param amount of unitized invoices (UPC) transferred
   */
  event TransferenceProcess(address indexed patron, address indexed recipient, uint256 value, uint256 amount);


  constructor(uint256 _startTime, uint256 _endTime, uint256 _rate) public {
    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_rate > 0);

    unitizedProofOfContribution = createUpcContract();
    startTime = _startTime;
    endTime = _endTime;
    rate = _rate;
    wallet = 0x7bf0586bd7fB8deF744d19dc5915907E0690e2aF;
  }

  // fallback function can be used for the transference process
  function () external payable {
    makeContribution(msg.sender);
  }

  // low level token purchase function
  function makeContribution(address recipient) public payable {
    require(recipient != address(0));
    require(validTransfer());

    uint256 weiAmount = msg.value;

    // calculate unitized invoice (UPC) amount to be created
    uint256 upc = getUpcAmount(weiAmount);

    // update state
    weiRaised = weiRaised.add(weiAmount);

    unitizedProofOfContribution.mint(recipient, upc);
    emit TransferenceProcess(msg.sender, recipient, weiAmount, upc);

    forwardFunds();
  }

  // @return true if fundraise event has ended
  function hasEnded() public view returns (bool) {
    return now > endTime;
  }

  // creates the UPC to be sold.
  function createUpcContract() internal returns (MintableUPC) {
    return new NCCReceipt();
  }

  // Override this method to have a way to add business logic
  function getUpcAmount(uint256 weiAmount) internal view returns(uint256) {
    return weiAmount.mul(rate);
  }

  // send ether to the collection wallet
  // override to create custom forwarding mechanisms
  function forwardFunds() internal {
    wallet.transfer(msg.value);
  }

  // @return true if the transaction can buy upc
  function validTransfer() internal view returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroTransfer = msg.value != 0;
    return withinPeriod && nonZeroTransfer;
  }

}

library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    require(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // require(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // require(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);
    return c;
  }
}

contract Ownable {
  address public owner;

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor () public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

}

contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract BasicUPC is ERC20Basic {
  using SafeMath for uint256;

  mapping(address => uint256) balances;

  uint256 totalSupply_;

  /**
  * @dev total number of upc in existence
  */
  function totalSupply() public view returns (uint256) {
    return totalSupply_;
  }

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);

    // SafeMath.sub will throw if ther§e is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

}

contract ERC20 is ERC20Basic {
  function allowance(address owner, address patron) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address patron, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed patron, uint256 value);
}

contract StandardUPC is ERC20, BasicUPC {

  mapping (address => mapping (address => uint256)) internal allowed;


  /**
   * @dev Transfer upc from one address to another
   * @param _from address The address which you want to send upc from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of upc to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to transfer the specified amount of upc on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the patron's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _patron The address which will transfer the support commitment.
   * @param _value The amount of upc to be transferred.
   */
  function approve(address _patron, uint256 _value) public returns (bool) {
    allowed[msg.sender][_patron] = _value;
    emit Approval(msg.sender, _patron, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of upc that an owner allowed to a patron.
   * @param _owner address The address which owns the support commitment.
   * @param _patron address The address which will transfer the support commitment.
   * @return A uint256 specifying the amount of upc still available for the patron.
   */
  function allowance(address _owner, address _patron) public view returns (uint256) {
    return allowed[_owner][_patron];
  }

  /**
   * @dev Increase the amount of upc that an owner allowed to a patron.
   *
   * approve should be called when allowed[_patron] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _patron The address which will transfer the support commitment.
   * @param _addedValue The amount of upc to increase the allowance by.
   */
  function increaseApproval(address _patron, uint _addedValue) public returns (bool) {
    allowed[msg.sender][_patron] = allowed[msg.sender][_patron].add(_addedValue);
    emit Approval(msg.sender, _patron, allowed[msg.sender][_patron]);
    return true;
  }

  /**
   * @dev Decrease the amount of upc that an owner allowed to a patron.
   *
   * approve should be called when allowed[_patron] == 0. To decrement
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _patron The address which will transfer the support commitment.
   * @param _subtractedValue The amount of upc to decrease the allowance by.
   */
  function decreaseApproval(address _patron, uint _subtractedValue) public returns (bool) {
    uint oldValue = allowed[msg.sender][_patron];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_patron] = 0;
    } else {
      allowed[msg.sender][_patron] = oldValue.sub(_subtractedValue);
    }
    emit Approval(msg.sender, _patron, allowed[msg.sender][_patron]);
    return true;
  }

}

contract MintableUPC is StandardUPC, Ownable {
  event Mint(address indexed to, uint256 amount);
  event MintFinished();

  bool public mintingFinished = false;


  modifier canMint() {
    require(!mintingFinished);
    _;
  }

  /**
   * @dev Function to mint upc
   * @param _to The address that will receive the minted upc.
   * @param _amount The amount of upc to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address _to, uint256 _amount) onlyOwner canMint public returns (bool) {
    totalSupply_ = totalSupply_.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    emit Mint(_to, _amount);
    emit Transfer(address(0), _to, _amount);
    return true;
  }

  /**
   * @dev Function to stop minting new upc.
   * @return True if the operation was successful.
   */
  function finishMinting() onlyOwner canMint public returns (bool) {
    mintingFinished = true;
    emit MintFinished();
    return true;
  }
}

contract NCCReceipt is MintableUPC {

  string public name = 'NCC Contribution Receipt';
  string public symbol = 'NCC';
  uint public decimals = 8;

}
