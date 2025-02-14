class ActiveStorage::DownloadableFile
  def self.create_list_from_dossiers(
    dossiers,
    with_bills: false,
    with_champs_private: false,
    include_infos_administration: false,
    include_avis_for_expert: false
  )
    PiecesJustificativesService.generate_dossier_export(dossiers, include_infos_administration:, include_avis_for_expert:) +
      PiecesJustificativesService.liste_documents(dossiers, with_bills:, with_champs_private:)
  end

  def self.cleanup_list_from_dossier(files)
    if Rails.application.config.active_storage.service != :openstack
      return files
    end

    files.filter do |file, _filename|
      if file.is_a?(ActiveStorage::FakeAttachment)
        true
      else
        service = file.blob.service
        client = service.client
        begin
          client.head_object(service.container, file.blob.key)
          true
        rescue Fog::OpenStack::Storage::NotFound
          false
        end
      end
    end
  end

  private

  def self.bill_and_path(bill)
    [
      bill,
      "bills/#{self.timestamped_filename(bill)}"
    ]
  end

  def self.pj_and_path(dossier_id, pj)
    [
      pj,
      "dossier-#{dossier_id}/#{self.timestamped_filename(pj)}"
    ]
  end

  def self.timestamped_filename(attachment)
    # we pad the original file name with a timestamp
    # and a short id in order to help identify multiple versions and avoid name collisions
    folder = self.folder(attachment)
    extension = File.extname(attachment.filename.to_s)
    basename = File.basename(attachment.filename.to_s, extension)
    timestamp = attachment.created_at.strftime("%d-%m-%Y-%H-%M")
    id = attachment.id % 10000

    [folder, "#{basename}-#{timestamp}-#{id}#{extension}"].join
  end

  def self.folder(attachment)
    if attachment.name == 'pdf_export_for_instructeur'
      return ''
    end

    case attachment.record_type
    when 'Dossier'
      'dossier/'
    when 'DossierOperationLog', 'BillSignature'
      'horodatage/'
    when 'Commentaire'
      'messagerie/'
    else
      'pieces_justificatives/'
    end
  end
end
