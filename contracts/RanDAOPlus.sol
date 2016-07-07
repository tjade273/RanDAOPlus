import "./ProofLib.sol";
contract RNG {
  using ProofLib for ProofLib.Proof;
  mapping(uint => uint) public randomNumbers; //Finalized random numbers. If non-zero, can be assumed final
  mapping(uint => pendingBlock) pending;  //Pending numbers

  struct Deposit {
    uint proposal;
    int amount; //Negative if betting against proposal, positive if betting for
  }

  struct pendingBlock{
    mapping(uint => uint) proposals; //Maps proposed solutions to amount staked
    mapping(address => Deposit) deposits; //Maps addresses to Deposits
    mapping(uint => ProofLib.Proof[]) proofs; //Maps proposal to array of proofs
    uint blockhash; //Seed for RNG
    uint totalFunds; //Total balance collected for this block
    uint depositLimit; //Limit above which proposals may be finalized -- new top proposal resets the limit
    uint difficulty; //Number of hashes on seed
    uint finalizeTime; // Block number at which top proposal becomes final;
  }

  uint public diff = 15000; //Start difficulty at 20, adjustment algo TBD
  uint public constant fee = 1 finney; //Minimum fee to buy random number
  uint public constant minDeposit = 1 ether;

  //Debugging events
  event DepositLimitChange(uint blockNum, uint limit);
  event NewProposal(uint blockNum, uint proposal, uint deposit);
  event NewChallenge(uint blockNum, uint proposal, address challenger, uint proofID);
  event ChallengeAccepted(uint blockNum, uint proposal, address defender, uint proofID);
  event FinalizeProof(uint blockNum, uint proposal, uint proofID, bool success);
  event Victory(uint blockNum, uint proposal);

  function buyNumber(uint blockNum){ //Increase security of number at block blockNum
    pending[blockNum].depositLimit += msg.value*10; //@debug Increase min deposit: depositLimit + `uint msg.value` * 10 = `uint pending[blockNum].depositLimit`
    pending[blockNum].totalFunds += msg.value;
    DepositLimitChange(blockNum, pending[blockNum].depositLimit);
  }

  function initBlock(uint blockNum){
    pending[blockNum].difficulty = diff;
    pending[blockNum].blockhash = uint(block.blockhash(blockNum)); // TODO, make sure not 0
  }

  function deposit(uint blockNum, uint proposal){
    if(blockNum > block.number || proposal == 0) throw; //@warn Don't let people bet on bocks in the future
    Deposit deposit = pending[blockNum].deposits[msg.sender]; // Get deposit for msg.sender
    if(deposit.proposal != 0 && deposit.proposal != proposal) throw; //@warn If they've already submitted a proposal, throw. They can make more accounts if they want more than one proposal (which they shouldn't)

    initBlock(blockNum);
    deposit.proposal = proposal; //@debug Set their proposal to the proposal (possibly overwrite with same value, a bit inefficient: `uint deposit.proposal`)
    deposit.amount += int(msg.value); //Add to their deposit (TODO: check for overflows)
    uint deposits = pending[blockNum].proposals[proposal]; // Store deposit total for later
    pending[blockNum].proposals[proposal] += msg.value; //Add their deposit to total value backing proposal
    pending[blockNum].totalFunds += msg.value; //Add deposit to total funds collected
    if(!(deposits >= pending[blockNum].depositLimit) && pending[blockNum].proposals[proposal] > pending[blockNum].depositLimit){  //If this is the new top proposal
      pending[blockNum].depositLimit = pending[blockNum].proposals[proposal];  //depositLimit increases
      pending[blockNum].finalizeTime += 3; // add another 3 blocks to the finalization deadline TODO: migrate to global, possibly dynamic variable
    }
    NewProposal(blockNum, proposal, pending[blockNum].proposals[proposal]);
  }

  function newChallenge(uint blockNum, uint proposal){ //Create new challenge
    if(msg.value < minDeposit) throw;  //@warn Don't allow deposits below min deposit: WHY?

    ProofLib.Proof[] proofs = pending[blockNum].proofs[proposal];
    proofs[proofs.length++].newChallenge(msg.sender, pending[blockNum].blockhash, proposal, diff, 20); // Create an new challenge with timeout 20. TODO: Dynamic timeouts?

    Deposit deposit = pending[blockNum].deposits[msg.sender];
    if(deposit.proposal != 0 && deposit.proposal != proposal) throw; //Don't let someone bet against more than one proposal TODO: Allow this
    deposit.proposal = proposal; // Set sender's proposal
    pending[blockNum].deposits[msg.sender].amount = -int(msg.value); //Set sender's deposit amout to negative to indicate nay vote
    pending[blockNum].proposals[proposal] -= msg.value; //Subtract from total value backing proposal TODO: check for underflow

    NewChallenge(blockNum, proposal, msg.sender, proofs.length -1);
  }

  function acceptChallenge(uint blockNum, uint proposal, uint proofIndex){
    pendingBlock p = pending[blockNum];
    if(p.deposits[msg.sender].proposal != proposal || //Don't allow defending on proposals that aren't yours
    p.deposits[msg.sender].amount < -p.deposits[p.proofs[proposal][proofIndex].challenger].amount) throw;  //Require a vested interest in the defense

    p.proofs[proposal][proofIndex].defender = msg.sender; // Set the sender as the defender TODO: don't overwrite defenders

    ChallengeAccepted(blockNum, proposal, msg.sender, proofIndex);
  }

  //Pure pass-through functions
  function challenge(uint blockNum, uint proposal, uint proofID, bool correct){ //Passthrough to ProofLib.challenge
    ProofLib.Proof proof = pending[blockNum].proofs[proposal][proofID]; // Fetch proof
    proof.challenge(correct);
  }

  function respond(uint blockNum, uint proposal, uint proofID, uint val){
    ProofLib.Proof proof = pending[blockNum].proofs[proposal][proofID]; // Fetch proof
    proof.respond(val);
  }

  function finalize(uint blockNum, uint proofIndex){ //Should only be called by challenger (TODO)

    uint proposal = pending[blockNum].deposits[msg.sender].proposal; //TODO: make sure this is a valid proposal
    address defender = pending[blockNum].proofs[proposal][proofIndex].defender;  //Get the defender
    address challenger = pending[blockNum].proofs[proposal][proofIndex].challenger; //Get the challenger
    int deposit;

    if(pending[blockNum].proofs[proposal][proofIndex].finalize()){ //Check if the challenge was successful
      deposit = pending[blockNum].deposits[defender].amount; //Get the deposit put down by the defender
      pending[blockNum].deposits[defender].amount = 0; //Defender loses, their deposit is taken
      pending[blockNum].deposits[challenger].amount -= deposit; //Make the deposit **More negative** TODO: Make sure that msg.sender really equals challenger
      FinalizeProof(blockNum, proposal, proofIndex, true);
    }
    else { //The defender wins
      deposit = pending[blockNum].deposits[challenger].amount;   //Get deposit by challenger
      pending[blockNum].deposits[challenger].amount = 0;    //challenger loses their deposit
      pending[blockNum].deposits[defender].amount -= deposit; // defender gets the challenger's deposit. (negative because challenger has negative deposit)
      FinalizeProof(blockNum, proposal, proofIndex, false);
    }

  }

  function declareVictor(uint blockNum, uint proposal){ //Finalize number. Once this is called, there should be no going back < TODO!!!!
    if(randomNumbers[blockNum] != 0 ||    // If there's already a number decided, throw. TODO: perform check upstream as well
        pending[blockNum].finalizeTime > block.number) throw;  // If the finalize time hasn't passed, don't finalize
    if(pending[blockNum].proposals[proposal] >= pending[blockNum].depositLimit){ // If the proposal deposits have passed the limit, it is finalized. TODO: make it stay above limin for time T
      randomNumbers[blockNum] = proposal; // Moment of truth....
      Victory(blockNum, proposal);
    }
    //consider throwing
  }

  function claimReward(uint blockNum){ //This needs to work, or all the game theory breaks down...
    uint proposal = pending[blockNum].deposits[msg.sender].proposal; //Fetch the user's proposal
    if(randomNumbers[blockNum] == proposal && //Only if they bet on the right thing
    pending[blockNum].deposits[msg.sender].amount > 0){ // And they bet for it, not against TODO: what happens to the loser's deposits?
      int amount = pending[blockNum].deposits[msg.sender].amount; // The amount they bet
      pending[blockNum].deposits[msg.sender].amount = 0; // Zero out deposit to prevent recursive call attacks
      if(!msg.sender.send((pending[blockNum].totalFunds * uint(amount))/pending[blockNum].proposals[proposal])) throw; // Send Total ammount collected for block * percent of winning bets the sender holds
    }
  }

  //Getters:
  function getDeposit(uint blockNum, address addr) constant returns(uint proposal, int amount){ //Gets the deposit for a given account at blockNum
    Deposit dep = pending[blockNum].deposits[addr];
    return(dep.proposal, dep.amount);
  }

  function getStake(uint blockNum, uint proposal) constant returns (uint){ //Gets the net stake on proposal (indicates finality)
    return pending[blockNum].proposals[proposal]; //Net stake on proposal
  }

  function getPendingBlock(uint blockNum) constant returns (uint[5]){ //Returns all statically enumerable info about pending block
    pendingBlock p = pending[blockNum];
    return [p.blockhash, p.totalFunds, p.depositLimit, diff, p.finalizeTime];
  }

  function getProof(uint blockNum, uint proposal, uint proofID) constant returns(address[2], uint[7]){
    ProofLib.Proof proof = pending[blockNum].proofs[proposal][proofID];

    return ([proof.defender, proof.challenger], [proof.lVal, proof.rVal, proof.lIndex, proof.rIndex, proof.roundTime, proof.lastRound, proof.currentVal]);
  }



  //Convinience Method for testing miner
  function sha(uint blockNum, uint diff) constant returns (uint){ // TODO: Make sure this returns the correct result
    bytes32 temp = block.blockhash(blockNum);
    for(uint i = 0; i< diff; i++){
      temp = sha3(temp);
    }
    return uint(temp);
  }
}
