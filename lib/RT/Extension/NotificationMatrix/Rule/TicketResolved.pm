package RT::Extension::NotificationMatrix::Rule::TicketResolved;
use strict;
use warnings;
use base 'RT::Extension::NotificationMatrix::Rule';

use constant NM_Entry => 'TicketResolved';
use constant DefaultTemplate => 'Resolved';
use constant Description => 'When ticket is resolved';

sub ConditionMatched {
    my $self = shift;
    $self->ScripConditionMatched("On Resolve");
}

1;
