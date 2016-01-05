# Stock Symbol Populator

Creates a Semantic Data Collection Changefile for Solve for All based on stock symbols downloaded from NASDAQ.
Populates stock symbols from the NASDAQ, NYSE, and AMEX exchanges.

## Usage

To run:

  bundle install
  ruby main.rb -d

should produce a bzipped Semantic Data Collection Changefile: stocks.json.bz2 in the project directory.

## More Info

See the [documentation on Semantic Data Collections](https://solveforall.com/docs/developer/semantic_data_collection) 
for more information.

Thanks to NASDAQ for providing this data!

## License

This project is licensed with the Apache License, Version 2.0. See LICENSE.
