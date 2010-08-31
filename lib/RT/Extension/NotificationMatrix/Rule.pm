package  RT::Extension::NotificationMatrix::Rule;
use strict;
use warnings;
use List::MoreUtils qw(part);
use RT::Action::SendEmail;
use base 'RT::Rule';

sub GetExternalRecipients {
    my $self = shift;
    return $self->GetRecipients(1);
}

sub GetRecipients {
    my ($self, $external) = @_;
    my $matrix = RT::Extension::NotificationMatrix->get_queue_matrix($self->TicketObj->QueueObj);

    my $t = $matrix->{$self->NM_Entry} or return;

    my $address;

    $self->ConditionMatched or return;

    my ($include, $exclude) = part { $_ > 0 ? 0 : 1 } @$t;

    for my $g (@$include) {
        my ($class, @addresses) = $self->_AddressesFromGroupWithClass($g, $external);
        $address->{$class}{$_} = 1 for @addresses;
    }

    for my $excluded (map { $self->_AddressesFromGroup(-$_, $external) } @$exclude ) {
        delete $address->{$_}{$excluded} for qw(To Cc Bcc);
    }

    return { map { $_ => [sort keys %{$address->{$_}} ] }
                 qw(To Cc Bcc) };
}

# external : requestor & cc

sub _AddressesFromGroup {
    my ($self, $id, $external) = @_;
    my ($class, @email) = $self->_AddressesFromGroupWithClass($id, $external);
    return @email;
}

sub _AddressesFromGroupWithClass {
    my ($self, $id, $external) = @_;
    my $g = RT::Group->new($self->CurrentUser);
    $g->Load($id);

    my $is_external = $g->Domain eq 'RT::Queue-Role' && ($g->Type eq 'Requestor' || $g->Type eq 'Cc');
    return if $external xor $is_external;

    my @emails = $g->MemberEmailAddresses;
    my $class = 'Bcc';

    if ($g->Domain eq 'RT::Queue-Role') {
        $g->LoadTicketRoleGroup( Ticket => $self->TicketObj->Id, Type => $g->Type );
        push @emails, $g->MemberEmailAddresses;
        $class = $g->Type eq 'Cc'      ? 'Cc'
               : $g->Type eq 'AdminCc' ? 'Bcc'
                                       : 'To';
    }

    return ($class, @emails);
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

sub DefaultExternalTemplate {
    $_[0]->DefaultTemplate;
}

sub LoadTemplate {
    my ($self, $external) = @_;
    my $template = RT::Template->new($self->CurrentUser);

    my $name = ref($self);
    $name =~ s/^RT::Extension::NotificationMatrix::Rule::// or die "unknown rule: $name";
    my @templates = $external ? ("$name-External", $self->DefaultExternalTemplate)
                              : ($name,            $self->DefaultTemplate);
    for my $tname (@templates, 'Transaction') {
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

sub PrepareExternal {
    my ($self) = @_;
    my $recipients = $self->GetExternalRecipients or return;

    my $template = $self->LoadTemplate(1);
    # RT::Action weakens the following, so we need to keep additional references
    my $ref = [RT::Scrip->new($self->CurrentUser),
               { _Message_ID => 0},
               $template];
    return $self->_PrepareSendEmail($recipients, $ref);
}

sub PrepareInternal {
    my ($self) = @_;
    my $recipients = $self->GetRecipients or return;

    my $template = $self->LoadTemplate;
    # RT::Action weakens the following, so we need to keep additional references
    my $ref = [RT::Scrip->new($self->CurrentUser),
               { _Message_ID => 0},
               $template];

    return $self->_PrepareSendEmail($recipients, $ref);
}

sub _PrepareSendEmail {
    my ($self, $recipients, $ref) = @_;

    my $email = RT::Action::SendEmail->new( Argument       => undef,
                                            CurrentUser    => $self->CurrentUser,
                                            ScripObj       => $ref->[0],
                                            ScripActionObj => $ref->[1],
                                            TemplateObj    => $ref->[2],
                                            TicketObj      => $self->TicketObj,
                                            TransactionObj => $self->TransactionObj );

    $email->{$_} = $recipients->{$_} for qw(To Cc Bcc);
    $email->{__ref} = $ref;
    $email->Prepare;
    return $email;
}

sub Prepare {
    my $self = shift;

    $self->{__email} = [($self->PrepareInternal(), $self->PrepareExternal())];
    $self->{hints} = { class => 'SendEmail',
                       recipients => { To =>  [ map { @{$_->{To}} } @{$self->{__email}} ],
                                       Cc =>  [ map { @{$_->{Cc}} } @{$self->{__email}} ],
                                       Bcc => [ map { @{$_->{Bcc}} } @{$self->{__email}} ],
                                   } };
    return 1;
}

sub Commit {
    my $self = shift;
    if ($self->{__email}) {
        $_->Commit for @{$self->{__email}};
    }

}

1;
