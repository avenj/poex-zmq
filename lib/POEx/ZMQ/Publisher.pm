package POEx::ZMQ::Publisher;


use Moo;
with 'POEx::ZMQ::Role::Socket';


around start => sub {
  my ($orig, $self, @endpoints) = @_;
  
};

around stop => sub {
  my ($orig, $self) = @_;

};


sub publish {

}


1;
