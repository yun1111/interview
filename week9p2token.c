//yes
#include<stdio.h>

char my_buffer;
int is_my_buffer_filled=0;

//char my_getchar();
////void my_buffer_fill(char ch);
//char peek_next();
//void identifier(char ch);
//int classify(char ch)
//void read(char);
//int main();

char my_getchar()   //If has buffer,return it.Or get next char.
{
    char ch;
    if(is_my_buffer_filled==0)
    {
        ch=getchar();
        return ch;
    }
    else if(is_my_buffer_filled==1)
    {
        is_my_buffer_filled=0;
        return my_buffer;
    }
}

void my_buffer_fill(char ch)  //fill my buffer
{
    my_buffer=ch;
    is_my_buffer_filled=1;
    return;
}

//�ݤU�@�ӡAbuffer�����N���X�ӦA��^�h�A�S���NŪ�@�Ӭݥ��é�Jbuffer
char peek_next()    //拿buffer的並放回去，或者拿新的並放到buffer
{
    char ch;
    ch=my_getchar();    
    my_buffer_fill(ch);
    return ch;
}
int classify(char ch)
{
        if((ch=='+')||(ch=='-')||(ch=='*')||(ch=='/')||(ch=='(')||ch==')')
        {
            //printf("%c\n",ch);
            return 0;
        }
        else if((ch>=48)&&(ch<=57))   //is number
        {
            //printf("%c\n",ch);
            return 2;
        }
        else if(((ch<=90)&&(ch>=65))||((ch>=97)&&(ch<=122))||(ch=='_'))  //is letter
            return 1;
        else if((ch==' ')||(ch=='\n')||(ch=='\t')||(ch=='\r'))   //換行或空白
        {
            //ch=ch;
            return 3;
        }
        else if((ch==',')||(ch=='.')||(ch=='?')||(ch=='\'')||(ch==':')||(ch=='\''))  //
        {
            //printf("%c\n",ch);
            return 0;
        }
        /*else
        {
            //printf("\"");
            //if(rcall==0)read(ch);
            //printf("\"\n");
            //else if(rcall==1)
            return 1;
        }*/
}
void identifier(char ch)
{
    char nextchar;
    //int recursive;
    int cont;
    printf("%c",ch);
    nextchar=peek_next();
    cont=classify(nextchar);
    if (cont==1||cont==2)
    {
        identifier(my_getchar()); //recursive. until next one isn't a identifier
    }
    else
    {
        printf("\"\n");
    }
    return;
}
void value(char ch)
{
    char nextchar;
    //int recursive;
    int cont;
    printf("%c",ch);
    nextchar=peek_next();
    cont=classify(nextchar);
    if (cont==2)
    {
        value(my_getchar());  //recursive. until not a number.
    }
    else
    {
        printf("\n");
    }
    //return;
}

int main()
{
    char ch;
    int call;
    ch = my_getchar();
    while (ch != EOF)
    {
        call=classify(ch);
        if((call==0)) //+-*...
        {
            printf("%c\n",ch);
        }
        else if(call==2) //number
        {
            value(ch);
        }
        else if(call==1) //letter
        {
            printf("\"");
            identifier(ch);
        }
        ch = my_getchar();
    }

    return 0;
}

/*if((ch=='+')||(ch=='-')||(ch=='*')||(ch=='/')||(ch=='(')||ch==')')
    {
        printf("%c\n",ch);
    }
    else if((ch>=48)&&(ch<=57))
    {
        printf("%c\n",ch);
    }
    else if()
*/
