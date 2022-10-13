#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>
#include "apue.h"

void put_pull_rod(int signum);
void fish_eating();
void exit_game(int signum);

int fishNum = 0; // counting fish number
int boolean = 0; // used as a boolean
int fish = 0;	 //0 no fish, 1 has fish
int bait = 0;	 //has bait?

int main(void)
{

	struct sigaction sig_put_pull_rod;
	sig_put_pull_rod.sa_handler = put_pull_rod;

	struct sigaction sig_exit_game;
	sig_exit_game.sa_handler = exit_game;

	//write your code here
	sigemptyset(&sig_put_pull_rod.sa_mask);
	sigaddset(&sig_put_pull_rod.sa_mask,SIGINT);


	sigaction(SIGINT, &sig_put_pull_rod, NULL);
	sigaction(SIGTSTP, &sig_exit_game, NULL);
	signal(SIGALRM, fish_eating);

	printf("Fishing rod is ready!\n");
	while (1)
	{
		pause();
	}

	return 0;
}

void put_pull_rod(int signum)
{
	//first time, put rod, set waiting time
	if (boolean == 0)
	{
		boolean = 1;
		fish = 0;
		bait = 1;

		int eat_time;

		printf("\nPut the fishing rod\n");
		sleep(1);
		printf("Bait into water, waiting fish...\n");

		srand(time(NULL));
		eat_time = (rand() % 2) + 1;
		alarm(eat_time);
	}
	//second time, pull rod, if success? how many fish in total?
	else if (boolean == 1)
	{
		boolean = 0;
		alarm(0);
		printf("\nPull the fishing rod\n");
		if (fish == 1)
		{
			//has fish!!
			fishNum++;
			printf("Catch a Fish!!\n");
			printf("\nTotally caught fishes: %d\n", fishNum);
		}
		else if (fish == 0)
		{
			if (bait == 0)
			{
				printf("The bait was eaten!!\n");
			}
		}
		printf("Fishing rod is ready!\n");
	}
}

void fish_eating()
{
	//first, start a fish
	if (fish == 0 && boolean == 1)
	{
		fish = 1;
		printf("A fish is biting,pull the fishing rod\n");
		alarm(5);
	}
	else if (fish == 1 && boolean == 1)
	{
		fish = 0;
		bait = 0;
		printf("The fish was escaped!!\n");
	}
}

void exit_game(int signum)
{
	printf("\nTotally caught fishes: %d\n", fishNum);
	exit(0);
}
