package RT::Extension::NotificationMatrix::Rule::TicketCreated;
use strict;
use warnings;
use base 'RT::Extension::NotificationMatrix::Rule';

use constant NM_Entry => 'TicketCreated';

sub ConditionMatched {
    my $self = shift;
    $self->ScripConditionMatched("On Create");
}

1;
