package RT::Extension::NotificationMatrix::Rule::QueueChanged;
use strict;
use warnings;
use base 'RT::Extension::NotificationMatrix::Rule';

use constant NM_Entry => 'QueueChanged';

sub ConditionMatched {
    my $self = shift;
    $self->ScripConditionMatched("On Queue Change");
}

1;
