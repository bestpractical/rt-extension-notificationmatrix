package RT::Extension::NotificationMatrix::Rule::TicketCommented;
use strict;
use warnings;
use base 'RT::Extension::NotificationMatrix::Rule';

use constant NM_Entry => 'TicketCommented';
use constant DefaultTemplate => 'Admin Comment';

sub ConditionMatched {
    my $self = shift;
    $self->ScripConditionMatched("On Commit");
}

1;
