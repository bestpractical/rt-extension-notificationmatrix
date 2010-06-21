package RT::Extension::NotificationMatrix::Rule::TicketResolved;
use strict;
use warnings;
use base 'RT::Extension::NotificationMatrix::Rule';

use constant NM_Entry => 'TicketResolved';

sub ConditionMatched {
    my $self = shift;
    $self->ScripConditionMatched("On Resolve");
}

1;
