-- =============================================
-- Script SQL de Inicialização
-- Disciplina: Infraestrutura e Serviços de TI
-- =============================================

CREATE DATABASE IF NOT EXISTS teste;
USE teste;

CREATE TABLE IF NOT EXISTS usuarios (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  nome       VARCHAR(100) NOT NULL,
  email      VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO usuarios (nome, email) VALUES
  ('João Silva',   'joao@email.com'),
  ('Maria Santos', 'maria@email.com'),
  ('Pedro Costa',  'pedro@email.com');

SELECT 'Banco inicializado com sucesso!' AS status;
SELECT * FROM usuarios;
