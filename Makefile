freqd : freqd.c config.h
	cc -o freqd -Wall -Wextra -pedantic -O3 freqd.c

clean :
	rm -f config.h freqd
