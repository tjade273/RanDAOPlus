library HashChallenge {

  enum Phase {Challenge, Response}

  struct Challenge{
    uint deposit;
    address challenger;
    address defender;

    uint lVal;
    uint rVal;
    bytes32 currentValue;

    Phase phase;
  }

  function newChallenge(Challenge self, uint dep, address defend, uint lVal, uint rVal){
    self.deposit = dep;
    self.challenger = msg.sender;
    self.defender = defend;
    self.lVal = lVal;
    self.rVal = rVal;
    self.phase = Phase.Challenge;
  }

  function challenge(Challeneg self, bool correct){
    if(rVal == lVal)
    if(correct){
      self.lVal = (rVal+lVal)/2;
    }
    else{
      self.rVal = (rVal+lVal)/2;
    }
    self.phase = Phase.Response;
}

  function respond(Challenge self, bytes32 response){
    self.currentValue = response;
    self.phase = Phase.Challenge;
  }
