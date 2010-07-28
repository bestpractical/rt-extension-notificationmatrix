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

=head Templates

For external notification, the first template found will be used:

=over

=item TicketResolved

=item Resolved

=item Transaction

=back

For internal notification, the first template found will be used:

=over

=item TicketResolved

=item Transaction

=back

=cut


1;
