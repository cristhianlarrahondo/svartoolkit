function h = erpt_file_md5(fpath)
%ERPT_FILE_MD5  MD5 hex de un archivo via java.security.MessageDigest.
%   Portable (sin toolboxes). Para el manifest de reproducibilidad.
    if ~isfile(fpath); h = '(no existe)'; return; end
    fid = fopen(fpath, 'r');
    if fid < 0; h = '(no legible)'; return; end
    bytes = fread(fid, Inf, '*uint8'); fclose(fid);
    md = java.security.MessageDigest.getInstance('MD5');
    md.update(bytes);
    db  = md.digest();            % java int8 array (signed)
    dig = mod(double(db), 256);   % -> 0..255
    h   = sprintf('%02x', dig);
end
