docker run --rm -v "$PWD":"$PWD" -w "$PWD" ligolang/ligo:0.26.0 compile contract contracts/swap.ligo -e main -s pascaligo > build/swap.tz
docker run --rm -v "$PWD":"$PWD" -w "$PWD" ligolang/ligo:0.26.0 compile contract contracts/token.ligo -e main -s pascaligo > build/token.tz
