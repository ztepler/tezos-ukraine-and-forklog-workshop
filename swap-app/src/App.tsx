import React, { useState } from 'react';
import './App.css';

import { TezosToolkit } from '@taquito/taquito';
import type { ContractAbstraction, Wallet } from '@taquito/taquito';
import { BeaconWallet } from '@taquito/beacon-wallet';
import { NetworkType } from '@airgap/beacon-sdk';

let Tezos: TezosToolkit;
let wallet: BeaconWallet;
const network = NetworkType.GRANADANET
const rpcUrl = 'https://rpc.tzkt.io/granadanet/';

let token: ContractAbstraction<Wallet>;
let swap: ContractAbstraction<Wallet>;
const tokenAddress = 'KT1UZqajUtDCNuBDqzi2dfLrB9PHECbyKbiz';
const tokenId = 5;
const swapAddress = 'KT1FzzfgjGG7fgNsHD8YPZhf1vaGExJXSi7j';

let userAddress: string;


async function sync() {
  Tezos = new TezosToolkit(rpcUrl);
  wallet = new BeaconWallet({
    name: 'Workshop Swap Example',
    preferredNetwork: network
  });

  wallet.requestPermissions({network: { type: network }});

  const activeAccount = await wallet.client.getActiveAccount();
  Tezos.setWalletProvider(wallet);
  console.log(activeAccount);

  token = await Tezos.wallet.at(tokenAddress);
  console.log('token', token);

  swap = await Tezos.wallet.at(swapAddress);
  console.log('swap', swap);

  userAddress = await wallet.getPKH();
  console.log('address', userAddress);
}

const AddSwap = () => {
  const [tokenId, setTokenId] = useState(0);
  const [askPrice, setAskPrice] = useState(0);

  const handleAsk = async () => {

    const updateOperators = token.methods.update_operators([{
        add_operator: {
          operator: swapAddress,
          token_id: tokenId,
          owner: userAddress
        }}])

    const listCall = swap.methods.list(askPrice, tokenId)

    const removeOperators = token.methods.update_operators([{
        remove_operator: {
          operator: swapAddress,
          token_id: tokenId,
          owner: userAddress
        }}])

    const batch = await Tezos.wallet.batch()
      .withContractCall(updateOperators)
      .withContractCall(listCall)
      .withContractCall(removeOperators)
      .send()
      .then((result) => {console.log('AddSwap result', result)})
      .catch((err) => {console.log('AddSwap error', err)})

  };

  return (
    <div>
      <h3>swap: list</h3>
      <div>
        <span>Token ID:</span>
        <input
          onChange={(e) => { setTokenId(parseInt(e.target.value)) }}
          defaultValue={tokenId}
        />
      </div>
      <div>
        <span>Ask price (mutez):</span>
        <input
          onChange={(e) => { setAskPrice(parseInt(e.target.value)) }}
          defaultValue={askPrice}
        />
      </div>
      <button onClick={ handleAsk }>ask</button>
    </div>
  )
}


function App() {
  return (
    <div className="App">
      <header className="App-header">
        <p>
          Tezos Workshop Example
        </p>
      </header>
      <button onClick={ sync }>sync</button>
      <hr/>
      <AddSwap/>
      <hr/>
    </div>
  );
}

export default App;
