package RT::Extension::NotificationMatrix::Rule::QueueChanged;
use strict;
use warnings;
use base 'RT::Extension::NotificationMatrix::Rule';

use constant NM_Entry => 'QueueChanged';
use constant Description => 'When queue of ticket is changed';

sub ConditionMatched {
    my $self = shift;
    $self->ScripConditionMatched("On Queue Change");
}

=head Templates

For external notification, the first template found will be used:

=over

=item QueueChanged-External

=item Transaction

=back

For internal notification, the first template found will be used:

=over

=item QueueChanged

=item Transaction

=back

=cut

1;
