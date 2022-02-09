// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract NameRegister {

    enum Stage {
        Commit,
        Reveal
    }
    
    struct CommitChoice {
        bytes32 commitment;
        uint256 revealDeadline;
        uint256 unlockTime;
        string name;
        Stage stage;
    }

    event NameAlreadyRegistered(address player, string name);
    event NameRegistered(address player, string name);

    // Initialisation
    uint256 public deposit; //Locking amount
    uint256 public lockTime; //Lock time in sec
    uint8 public revealSpan;
    
    mapping (address => CommitChoice) private _userNameRegRequests;
    mapping (address => uint256[]) private _userRegisteredNameIDList;
    string[] private _registeredNames;
    uint256 private nameCost;
    
    /**
     * @dev Constructor to set initial settings
     * @param _deposit uint256 required amount in wei to commit. It will be locked
     * @param _lockTime uint256 time in sec to lock deposit
     * @param _nameCost uint256 cost required for a byte length
     */
    constructor(uint256 _deposit, uint256 _lockTime, uint256 _nameCost) {
        deposit = _deposit;
        revealSpan = 32; // 32 blocks
        lockTime = _lockTime;
        nameCost = _nameCost;
    }

    /**
     * @dev Public function to commit, payable
     * @param commitment bytes32 hash code that contains your account, name, and salt
     */
    function commit(bytes32 commitment) public payable {
        
        //Stage check
        require(_userNameRegRequests[msg.sender].stage == Stage.Commit, "NameRegister: Invalid stage");
        
        //Deposit check
        require(msg.value == deposit, "NameRegister: Value must be equal to deposit amount");
        
        // Store the commitment
        _userNameRegRequests[msg.sender] = CommitChoice(commitment, block.number + revealSpan, block.timestamp + lockTime , "", Stage.Reveal);
        
    }

    /**
     * @dev Public function to reveal, payable. You will be blocked to reveal until 32 blocks
     * @param name string name you want to register
     * @param blindingFactor bytes32 salt you used to create commitment.
     */
    function reveal(string memory name, bytes32 blindingFactor) public payable {

        require (_userNameRegRequests[msg.sender].stage == Stage.Reveal, "NameRegister: Invalid stage");

        require(bytes(name).length > 0, "NameRegister: Must have valid name");

        require(_userNameRegRequests[msg.sender].revealDeadline <= block.number, "NameRegister: Not ready to reveal");

        // Check the hash to ensure the commitment is correct
        require(keccak256(abi.encodePacked(msg.sender, name, blindingFactor)) == _userNameRegRequests[msg.sender].commitment, "invalid hash");

        if (!this.isDuplicated(name)) {
            //Should make payment for the name
            uint256 requiredAmount = _getPriceToRegisterName(name);
            require(requiredAmount <= msg.value + deposit, "NameRegister: Insufficient funds to register name.");
            require(requiredAmount > 0, "NameRegister: Invalid name.");
            if (requiredAmount < (msg.value + deposit)) {
                //Return the remain
                (bool success, ) = payable(msg.sender).call{value:(msg.value + deposit - requiredAmount)}("");
                require(success, "NameRegister: Refund failed.");
            }
            
            //You can register the name now
            _userRegisteredNameIDList[msg.sender].push(_registeredNames.length); //Save Name ID            
            _registeredNames.push(name);

            emit NameRegistered(msg.sender, name);
        }
        else {
            //Already registered. You should refund fully
            (bool success, ) = payable(msg.sender).call{value:msg.value + deposit}("");
            require(success, "NameRegister: Refund failed.");
            emit NameAlreadyRegistered(msg.sender, name);
        }

        //Init request
        delete _userNameRegRequests[msg.sender];
        
    }

    /**
     * @dev Private function to calc the amount based on the name length
     * @param name string name you want to register
     * @return bytes32 price you have to pay
     */
    function _getPriceToRegisterName(string memory name) private view returns (uint256) {
        return bytes(name).length * nameCost;
    }

    /**
     * @dev External function to check if this is duplicated string
     * @param name string name you want to register
     * @return bool true if it is already registered
     */
    function isDuplicated(string memory name) external view returns(bool) {
        for (uint256 idx = 0; idx < _registeredNames.length; idx++) {
            if (keccak256(abi.encodePacked(_registeredNames[idx])) == keccak256(abi.encodePacked(name))) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Public function to withdraw funds in lock after certain time. You should deposit first to register name
     */
    function withdraw() public {
        require(_userNameRegRequests[msg.sender].stage == Stage.Reveal, "NameRegister: Nothing to withdraw");
        require(block.timestamp >= _userNameRegRequests[msg.sender].unlockTime, "NameRegister: Funds in lock.");

        (bool success, ) = payable(msg.sender).call{value:deposit}("");
        require(success, "NameRegister: Refund failed.");
        
        //Init request
        delete _userNameRegRequests[msg.sender];
    }
}