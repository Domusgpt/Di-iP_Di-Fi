class ContractConfig {
  static const usdcAddress = String.fromEnvironment(
    'USDC_CONTRACT',
    defaultValue: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359', // Polygon Amoy Testnet USDC
  );

  static const crowdsaleAddress = String.fromEnvironment(
    'CROWDSALE_CONTRACT',
    defaultValue: '0x0000000000000000000000000000000000000000',
  );

  static const ipNftAddress = String.fromEnvironment(
    'IPNFT_CONTRACT',
    defaultValue: '0x0000000000000000000000000000000000000000',
  );
}
