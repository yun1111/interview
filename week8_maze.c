//yes.
//遞迴時不要用return來呼叫函式(因為return後面的不會做，它若可以走兩條路，只會走一條。return 完它會跳出迴圈)
#include<stdio.h>
int explore_map(const int n,const int m,const int grid_map[n][m],int reachable[n][m],
                const int k,const int directions[k][2],const int current_position[2])
                {
                    int x=current_position[1];
                    int y=current_position[0];
                    int i,j;
                    int next_position[2];
                    reachable[y][x]=1;

                    for(i=0;i<k;i++)
                    {
                        x=x+directions[i][1];
                        y=y+directions[i][0];

                        if((x>=m)||(x<0)||(y>=n)||(y<0))
                            i=i;
                        else if((grid_map[y][x]==0)&&(reachable[y][x]==0))
                        {
                            next_position[0]=y;
                            next_position[1]=x;
                            reachable[y][x]=1;

                            explore_map(n,m,grid_map,reachable,k,directions,next_position);

                        }

                        x=x-directions[i][1];
                        y=y-directions[i][0];
                    }

                    return 0;
                }


int main()
{
    int i,j,k;
    int n, m;

    scanf("%d%d", &n, &m);

    int grid_map[n][m];

    for(i=0;i<n;i++)
        for(j=0;j<m;j++)
            scanf("%d", &grid_map[i][j]);

    int reachable[n][m];

    for(i=0;i<n;i++)
        for(j=0;j<m;j++)
            reachable[i][j] = 0;

    int s1, s2;

    scanf("%d%d", &s1, &s2);

    int directions[4][2] = { {-1,0}, {0,-1}, {1,0}, {0,1} };
    int positions[2] = { s1, s2 };

    explore_map(n, m, grid_map, reachable,
                4, directions, positions );

    scanf("%d%d", &s1, &s2);

    for(i=0;i<n;i++)
    {
        printf("\n");
        for(j=0;j<m;j++)
            printf("%d ",reachable[i][j]);
        //printf("\n");
    }

    if(reachable[s1][s2])
        printf("yes\n");
    else
        printf("no\n");

    return 0;
}

