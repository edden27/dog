#include <bits/stdc++.h>
using namespace std;
#define fast_cin()                    \
	ios_base::sync_with_stdio(false); \
	cin.tie(NULL);
// Linkedlist to insert node at begining

struct Node
{
    int data;
    Node* next;
};
Node* head = new Node();
int inpt(int a)
{
    Node*temp = head;
    Node* A = new Node();
    A->data=a;
    A->next=head;
    head = A;
}

void outp()
{
    Node* temp = head;
    cout<<"The List is \n";
    while(temp->next !=NULL)
    {
        cout<<temp->data<<"\n";
        temp = temp->next;
    }

}

int main()
{
    int n;
    cout<<"Enter No of elements\n";
    cin>>n;
    
    while(n--)
    {
        int x;
        cin>>x;
        inpt(x);
    }
    outp();
}
