package  RT::Extension::NotificationMatrix::Rule;
use strict;
use warnings;
use List::MoreUtils qw(part);
use RT::Action::SendEmail;
use base 'RT::Rule';

sub GetRecipients {
    my $self   = shift;
    my $matrix = RT::Extension::NotificationMatrix->get_queue_matrix($self->TicketObj->QueueObj);

    my $t = $matrix->{$self->NM_Entry} or return;

    $self->ConditionMatched or return;
    my ($include, $exclude) = part { $_ > 0 ? 0 : 1 } @$t;

    my %address = map { $_ => 1 }
        map { $self->_AddressesFromGroup($_) } @$include;

    for (map { $self->_AddressesFromGroup(-$_) } @$exclude ) {
        delete $address{$_};
    }

    return sort keys %address;

}

sub _AddressesFromGroup {
    my ($self, $id) = @_;
    my $g = RT::Group->new($self->CurrentUser);
    $g->Load($id);
    my @emails = $g->MemberEmailAddresses;
    if ($g->Domain eq 'RT::Queue-Role') {
        $g->LoadTicketRoleGroup( Ticket => $self->TicketObj->Id, Type => $g->Type);
        push @emails, $g->MemberEmailAddresses;
    }
    return @emails;
}

sub ScripConditionMatched {
    my $self = shift;
    my $name = shift;

    my $ConditionObj = RT::ScripCondition->new( $self->CurrentUser );
    $ConditionObj->Load( $name ) or die;

    my $txn_type = $self->TransactionObj->Type;
    return unless( $ConditionObj->ApplicableTransTypes =~ /(?:^|,)(?:Any|\Q$txn_type\E)(?:,|$)/i );
    # Load the scrip's Condition object
    $ConditionObj->LoadCondition(
        ScripObj       => $self,
        TicketObj      => $self->TicketObj,
        TransactionObj => $self->TransactionObj,
    );

    return $ConditionObj->IsApplicable();
}

sub DefaultTemplate {}

sub LoadTemplate {
    my $self = shift;
    my $template = RT::Template->new($self->CurrentUser);

    my $name = ref($self);
    $name =~ s/^RT::Extension::NotificationMatrix::Rule::// or die "unknown rule: $name";

    for my $tname ($self->TicketObj->QueueObj->Name.'-'.$name, $name, $self->DefaultTemplate, 'Transaction') {
        $template->Load($tname);
        last if $template->Id;
    }

    unless ($template->Id) {
        die 'Failed to load template for notification rule: '.$name;
    }

    return $template;
}

sub Description {
    my $self = shift;
    my $name = ref($self) || $self;
    $name =~ s/^RT::Extension::NotificationMatrix::Rule::// or die "unknown rule: $name";
    return "Notification for $name";
}

sub Prepare {
    my $self = shift;

    my @recipients = $self->GetRecipients or return 0;

    my $template = $self->LoadTemplate;
    # RT::Action weakens the following, so we need to keep additional references
    my $ref = [RT::Scrip->new($self->CurrentUser),
               { _Message_ID => 0},
               $template];
    my $email = RT::Action::SendEmail->new( Argument       => undef,
                                            CurrentUser    => $self->CurrentUser,
                                            ScripObj       => $ref->[0],
                                            ScripActionObj => $ref->[1],
                                            TemplateObj    => $ref->[2],
                                            TicketObj      => $self->TicketObj,
                                            TransactionObj => $self->TransactionObj,
                                        );
    $email->{To} = \@recipients;
    $email->Prepare;
    $self->{__ref} = $ref;
    $self->{__email} = $email;
    $self->{hints} = { class => 'SendEmail',
                       recipients => { To => \@recipients } };
    return 1;
}

sub Commit {
    my $self = shift;
    if ($self->{__email}) {
        $self->{__email}->Commit;
    }

}

1;
