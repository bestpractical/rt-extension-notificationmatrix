package RT::Extension::NotificationMatrix::Rule::TicketCommented;
use strict;
use warnings;
use base 'RT::Extension::NotificationMatrix::Rule';

use constant NM_Entry => 'TicketCommented';
use constant DefaultTemplate => 'Admin Comment';
use constant Description => 'When ticket is commented';

sub ConditionMatched {
    my $self = shift;
    $self->ScripConditionMatched("On Comment");
}

=head Templates

For external notification, the first template found will be used:

=over

=item TicketCommented

=item Transaction

=back

For internal notification, the first template found will be used:

=over

=item TicketCommented

=item Admin Comment

=item Transaction

=back

=cut


1;
