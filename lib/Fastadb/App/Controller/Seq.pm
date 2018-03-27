package Fastadb::App::Controller::Seq;

use Mojo::Base 'Mojolicious::Controller';

sub id {
  my ($self) = @_;
  my $id = $self->param('id');
  my $start = $self->param('start');
  my $end = $self->param('end');

  my $range = $self->req->headers->range;
  if($range) {
    if($start || $end) {
      return $self->render(text => 'Invalid Input', status => 400);
    }
    #Parse header. Increase end by one as byte ranges are always from 0
    if(($start,$end) = $range =~ /(\d+)-(\d+)/) {
      $end++;
    }
    else {
      return $self->render(text => 'Invalid Input', status => 400);
    }
  }

  my $seq = $self->db()->resultset('Seq')->get_seq($id);
  if(!$seq) {
    return $self->render(text => 'Not Found', status => 404);
  }
  # Only when we're handling circular sequences
  if(!$seq->circular() && ($start && $end && $start > $end)) {
    return $self->render(text => 'Range Not Satisfiable', status => 416);
  }
  if($start && $start > $seq->size()) {
    return $self->render(text => 'Invalid Range', status => 400);
  }
  if($end && $end > $seq->size()) {
    return $self->render(text => 'Invalid Range', status => 400);
  }

  # Check for content specification. If nothing was specified then set to TXT
  if(!$self->content_specified()) {
    $self->stash->{format} = 'txt';
  }

  # Now check for status and set to 206 for partial rendering if we got a subseq from
  # Range but not the whole sequence
  my $status = 200;
  if($range) {
    $self->res->headers->accept_ranges('none');
    my $requested_size = $end-$start;
    if($requested_size != $seq->size()) {
      $status = 206;
    }
  }

  $self->respond_to(
    txt => sub { $self->render(data => $seq->get_seq($start, $end), status => $status); },
    fasta => sub { $self->render(data => $seq->to_fasta($start, $end)); },
    any => { data => 'Unsupported Media Type', status => 415 }
  );
}

1;