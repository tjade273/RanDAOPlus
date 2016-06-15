contract testProof{

  struct Proof{
    address defender;
    address challenger;

    uint deposit;

    bytes32 lVal;
    bytes32 rVal;
    uint lIndex;
    uint rIndex;

    bytes32 currentVal;

    //TODO: Implement non-participation resilliancy
  }

  //mapping(bytes32 => mapping(address => ))
  Proof[] proofs;

  function newChallenge(address _defender, address _challenger, uint _deposit, bytes32 seed, bytes32 result, uint difficulty){
    Proof self = proofs[proofs.length++];
    self.defender = _defender;
    self.challenger = _challenger;

    self.deposit = _deposit;

    self.lVal = seed;
    self.rVal = result;

    self.lIndex = 0;
    self.rIndex = difficulty;


  }

  function challenge(uint index, bool correct){
    Proof self=proofs[index];
    if(self.currentVal == 0 || msg.sender != self.challenger) throw;
    if(correct){
      self.lIndex = (self.lIndex + self.rIndex)/2;
      self.lVal = self.currentVal;
    }
    else{
      self.rIndex = (self.lIndex + self.rIndex)/2;
      self.rVal = self.currentVal;
    }

    self.currentVal = 0;
  }

  function respond(uint index, bytes32 hash){
    Proof self=proofs[index];
    if(self.currentVal != 0 || msg.sender != self.defender) throw;
    self.currentVal = hash;
  }

  function finalize(uint index) returns (bool confirmed){
    Proof self=proofs[index];
    if(self.rIndex - self.lIndex <= 3){
      bytes32 hash = self.lVal;

      for(uint i; i < self.rIndex - self.lIndex; i++){
        hash = sha3(hash);
      }

      if(hash == self.rVal){
        self.defender.send(self.deposit*2);
        return true;
      }
      else{
        self.challenger.send(self.deposit*2);
        return false;
      }
    }
    else throw;
  }

 function getProof(uint id) constant returns(uint,uint,bytes32,bytes32,bytes32){
     return (proofs[id].lIndex,proofs[id].rIndex,proofs[id].lVal,proofs[id].currentVal, proofs[id].rVal);
 }

 function sha(bytes32 seed) constant returns(bytes32){
     return sha3(seed);
 }

}
