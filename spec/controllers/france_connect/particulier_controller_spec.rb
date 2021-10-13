describe FranceConnect::ParticulierController, type: :controller do
  let(:birthdate) { '20150821' }
  let(:email) { 'EMAIL_from_fc@test.com' }

  let(:user_info) do
    {
      france_connect_particulier_id: 'blablabla',
      given_name: 'titi',
      family_name: 'toto',
      birthdate: birthdate,
      birthplace: '1234',
      gender: 'M',
      email_france_connect: email
    }
  end

  describe '#auth' do
    subject { get :login }

    it { is_expected.to have_http_status(:redirect) }
  end

  describe '#callback' do
    let(:code) { 'plop' }

    subject { get :callback, params: { code: code } }

    context 'when params are missing' do
      subject { get :callback }

      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when param code is missing' do
      let(:code) { nil }

      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when param code is empty' do
      let(:code) { '' }

      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when code is correct' do
      before do
        allow(FranceConnectService).to receive(:retrieve_user_informations_particulier)
          .and_return(FranceConnectInformation.new(user_info))
      end

      context 'when france_connect_particulier_id exists in database' do
        let!(:fci) { FranceConnectInformation.create!(user_info.merge(user_id: fc_user&.id)) }

        context 'and is linked to an user' do
          let(:fc_user) { create(:user, email: 'associated_user@a.com') }

          it { expect { subject }.not_to change { FranceConnectInformation.count } }

          it 'signs in with the fci associated user' do
            subject
            expect(controller.current_user).to eq(fc_user)
            expect(fc_user.reload.loged_in_with_france_connect).to eq(User.loged_in_with_france_connects.fetch(:particulier))
          end

          context 'and the user has a stored location' do
            let(:stored_location) { '/plip/plop' }
            before { controller.store_location_for(:user, stored_location) }

            it { is_expected.to redirect_to(stored_location) }
          end
        end

        context 'and is linked an instructeur' do
          let(:fc_user) { create(:instructeur, email: 'another_email@a.com').user }

          before { subject }

          it do
            expect(response).to redirect_to(new_user_session_path)
            expect(flash[:alert]).to be_present
          end
        end

        context 'and is not linked to an user' do
          let(:fc_user) { nil }

          context 'and no user with the same email exists' do
            it 'creates an user with the same email and log in' do
              expect { subject }.to change { User.count }.by(1)

              user = User.last

              expect(user.email).to eq(email.downcase)
              expect(controller.current_user).to eq(user)
              expect(response).to redirect_to(root_path)
            end
          end

          context 'and an user with the same email exists' do
            let!(:preexisting_user) { create(:user, email: email) }

            it 'redirects to the merge process' do
              expect { subject }.not_to change { User.count }

              expect(response).to redirect_to(france_connect_particulier_merge_path(fci.reload.merge_token))
            end
          end
        end
      end

      context 'when france_connect_particulier_id does not exist in database' do
        it { expect { subject }.to change { FranceConnectInformation.count }.by(1) }

        describe 'FranceConnectInformation attributs' do
          let(:stored_fci) { FranceConnectInformation.last }

          before { subject }

          it { expect(stored_fci).to have_attributes(user_info.merge(birthdate: Time.zone.parse(birthdate).to_datetime)) }
        end

        it { is_expected.to redirect_to(root_path) }
      end
    end

    context 'when code is not correct' do
      before do
        allow(FranceConnectService).to receive(:retrieve_user_informations_particulier) { raise Rack::OAuth2::Client::Error.new(500, error: 'Unknown') }
        subject
      end

      it { expect(response).to redirect_to(new_user_session_path) }

      it { expect(flash[:alert]).to be_present }
    end
  end

  describe '#merge' do
    let(:fci) { FranceConnectInformation.create!(user_info) }
    let(:merge_token) { fci.create_merge_token! }

    subject { get :merge, params: { merge_token: merge_token } }

    context 'when the merge token is valid' do
      it { expect(subject).to have_http_status(:ok) }
    end

    context 'when the merge token is invalid' do
      before do
        merge_token
        fci.update(merge_token_created_at: 2.years.ago)
      end

      it do
        expect(subject).to redirect_to root_path
        expect(flash.alert).to eq('Votre compte FranceConnect a expiré, veuillez recommencer.')
      end
    end

    context 'when the merge token does not exist' do
      let(:merge_token) { 'i do not exist' }

      it do
        expect(subject).to redirect_to root_path
        expect(flash.alert).to eq('Votre compte FranceConnect a expiré, veuillez recommencer.')
      end
    end
  end
end
